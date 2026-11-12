#!/usr/bin/env python3
"""Install pinned optional skills and runtimes without starting external tools."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class InstallError(Exception):
    """A refused or unsuccessful installation."""


def absolute(path: Path) -> Path:
    return Path(os.path.abspath(path.expanduser()))


def is_link(path: Path) -> bool:
    try:
        info = path.lstat()
    except FileNotFoundError:
        return False
    return stat.S_ISLNK(info.st_mode) or bool(
        getattr(info, "st_file_attributes", 0)
        & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    )


def check_path(path: Path) -> None:
    """Reject links/reparse points, including dangling links and ancestors."""
    for item in (path, *path.parents):
        if is_link(item):
            raise InstallError(f"refusing symlink or reparse point: {item}")
        if item != path and item.exists() and not item.is_dir():
            raise InstallError(f"path ancestor is not a directory: {item}")


def check_outside_repository(path: Path) -> None:
    resolved = path.resolve()
    repository = REPOSITORY_ROOT.resolve()
    if resolved == repository or repository in resolved.parents:
        raise InstallError(f"installation paths must be outside the portable repository: {path}")


def relative_path(value: str) -> str:
    if not isinstance(value, str) or not value or "\\" in value:
        raise InstallError(f"invalid manifest path: {value!r}")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or ":" in value or str(path) != value:
        raise InstallError(f"unsafe manifest path: {value!r}")
    return value


def file_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inventory(path: Path) -> dict[str, str]:
    check_path(path)
    if path.is_file():
        return {".": file_digest(path)}
    if not path.is_dir():
        raise InstallError(f"expected regular file or directory: {path}")
    result = {".": "directory"}
    for item in sorted(path.rglob("*")):
        if is_link(item):
            raise InstallError(f"refusing symlink or reparse point: {item}")
        relative = item.relative_to(path).as_posix()
        if item.is_dir():
            result[relative] = "directory"
        elif item.is_file():
            result[relative] = file_digest(item)
        else:
            raise InstallError(f"refusing special file: {item}")
    return result


def check_destination(source: Path | None, destination: Path) -> None:
    check_path(destination)
    if destination.exists():
        if source is None:
            raise InstallError(f"cannot compare existing destination without pinned source: {destination}")
        if inventory(source) != inventory(destination):
            raise InstallError(f"different content exists; refusing to overwrite: {destination}")


def install_copy(source: Path, destination: Path) -> None:
    check_destination(source, destination)
    if destination.exists():
        print(f"ok: already installed {destination}")
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    check_path(destination)
    if source.is_dir():
        # copytree reserves the destination with exclusive mkdir; it cannot overwrite.
        shutil.copytree(source, destination)
    else:
        with source.open("rb") as incoming, destination.open("xb") as outgoing:
            shutil.copyfileobj(incoming, outgoing)
        shutil.copymode(source, destination)
    print(f"installed: {destination}")


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments], check=False, text=True, capture_output=True,
        env={**os.environ, "GIT_TERMINAL_PROMPT": "0", "GIT_OPTIONAL_LOCKS": "0"},
    )
    if result.returncode:
        raise InstallError(f"git failed: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout.strip()


def verify_checkout(path: Path, package: dict) -> None:
    check_path(path)
    if not (path / ".git").is_dir() or is_link(path / ".git"):
        raise InstallError(f"source is not an ordinary Git checkout: {path}")
    actual = git("-C", str(path), "rev-parse", "HEAD")
    if actual != package["commit"]:
        raise InstallError(f"source pin mismatch at {path}: {actual}; expected {package['commit']}; not changing it")
    if git("-C", str(path), "status", "--porcelain", "--untracked-files=all", "--ignored"):
        raise InstallError(f"source checkout is dirty; refusing modified or extra files: {path}")
    for name in package["license_files"]:
        license_path = path / name
        check_path(license_path)
        if not license_path.is_file():
            raise InstallError(f"license missing from pinned source: {license_path}")
    if package["kind"] == "skill":
        skill = path / package["skill_path"]
        inventory(skill)
        if not (skill / "SKILL.md").is_file():
            raise InstallError(f"SKILL.md missing from pinned source: {skill}")


def checkout_source(root: Path, name: str, package: dict, apply: bool) -> Path | None:
    destination = root / f"{name}-{package['commit']}"
    check_path(destination)
    if destination.exists():
        verify_checkout(destination, package)
        return destination
    if not apply:
        print(f"[dry-run] shallow fetch {package['repository']} at {package['commit']} -> {destination}")
        return None
    root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f".{name}-", dir=root) as temporary:
        staged = Path(temporary) / "source"
        git("init", str(staged))
        git("-C", str(staged), "fetch", "--depth", "1", "--", package["repository"], package["commit"])
        git("-C", str(staged), "-c", "core.autocrlf=false", "checkout", "--detach", package["commit"])
        verify_checkout(staged, package)
        # An exclusive directory creation protects an existing checkout even in a race.
        destination.mkdir()
        for child in staged.iterdir():
            shutil.move(str(child), str(destination / child.name))
    return destination


def platform_key() -> str:
    system = {"Linux": "linux", "Darwin": "macos", "Windows": "windows"}.get(platform.system())
    machine = platform.machine().lower()
    architecture = {"amd64": "x86_64", "x86_64": "x86_64", "aarch64": "arm64", "arm64": "arm64"}.get(machine)
    if not system or not architecture:
        raise InstallError(f"unsupported operating system or architecture: {platform.system()} / {machine}")
    return f"{system}-{architecture}"


def load_packages(path: Path, requested: str) -> dict:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise InstallError("unsupported optional manifest schema_version")
    selected = ("hallmark", "codync") if requested == "all" else (requested,)
    packages = {}
    for name in selected:
        package = manifest["packages"][name]
        if package.get("kind") != ("skill" if name == "hallmark" else "runtime"):
            raise InstallError(f"unexpected package kind: {name}")
        if not re.fullmatch(r"[0-9a-f]{40}", package.get("commit", "")):
            raise InstallError(f"invalid source commit: {name}")
        if not re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.git", package.get("repository", "")):
            raise InstallError(f"invalid GitHub source URL: {name}")
        if not package.get("license_files"):
            raise InstallError(f"missing license_files: {name}")
        for license_name in package["license_files"]:
            relative_path(license_name)
        if name == "hallmark":
            relative_path(package["skill_path"])
            if package.get("skill_name") != "hallmark":
                raise InstallError("unexpected Hallmark skill_name")
        else:
            if not re.fullmatch(r"v?[0-9][A-Za-z0-9._-]*", package.get("version", "")):
                raise InstallError("invalid Codync version")
            key = platform_key()
            if key not in package.get("assets", {}):
                raise InstallError(f"Codync has no pinned host asset for {key}; use WSL with its Linux installer or the official desktop app")
            asset = package["assets"][key]
            if not re.fullmatch(r"[0-9a-f]{64}", asset.get("sha256", "")):
                raise InstallError(f"invalid asset SHA256: {key}")
            if not asset.get("url", "").startswith("https://github.com/leepokai/Codync/releases/download/"):
                raise InstallError("unexpected Codync release URL")
            if asset.get("format") not in {"tar.gz", "zip"}:
                raise InstallError("unsupported Codync archive format")
            relative_path(asset["archive_member"])
            executable = relative_path(asset["executable"])
            if "/" in executable:
                raise InstallError("runtime executable must be a filename")
        packages[name] = package
    return packages


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "ai-agent-portable/1"})
    with urllib.request.urlopen(request, timeout=60) as response, destination.open("xb") as output:
        shutil.copyfileobj(response, output)


def extract_executable(archive: Path, asset: dict, destination: Path) -> None:
    """Read exactly one regular archive member, never use extract/extractall."""
    wanted = asset["archive_member"]
    if asset["format"] == "tar.gz":
        with tarfile.open(archive, "r:gz") as bundle:
            matches = []
            for member in bundle.getmembers():
                # Reject traversal entries and links even when not selected.
                normalized = member.name.removeprefix("./")
                if member.isdir():
                    normalized = normalized.rstrip("/")
                if normalized in {"", "."} and member.isdir():
                    continue
                relative_path(normalized)
                if member.issym() or member.islnk() or not (member.isfile() or member.isdir()):
                    raise InstallError(f"unsafe archive member: {member.name}")
                if normalized == wanted:
                    matches.append(member)
            if len(matches) != 1 or not matches[0].isfile():
                raise InstallError(f"archive must contain one regular executable: {wanted}")
            with bundle.extractfile(matches[0]) as incoming, destination.open("xb") as outgoing:
                shutil.copyfileobj(incoming, outgoing)
    else:
        with zipfile.ZipFile(archive) as bundle:
            matches = []
            for member in bundle.infolist():
                normalized = member.filename.rstrip("/")
                relative_path(normalized)
                mode = member.external_attr >> 16
                if stat.S_IFMT(mode) not in {0, stat.S_IFREG, stat.S_IFDIR}:
                    raise InstallError(f"unsafe archive member: {member.filename}")
                if normalized == wanted:
                    matches.append(member)
            if len(matches) != 1 or matches[0].is_dir():
                raise InstallError(f"archive must contain one regular executable: {wanted}")
            with bundle.open(matches[0]) as incoming, destination.open("xb") as outgoing:
                shutil.copyfileobj(incoming, outgoing)
    destination.chmod(0o755)


def stage_runtime(package: dict, source: Path, temporary: Path) -> Path:
    key = platform_key()
    asset = package["assets"][key]
    archive = temporary / "download"
    download(asset["url"], archive)
    if file_digest(archive) != asset["sha256"]:
        raise InstallError("Codync archive SHA256 mismatch; refusing installation")
    staged = temporary / "runtime"
    staged.mkdir()
    extract_executable(archive, asset, staged / asset["executable"])
    for license_name in package["license_files"]:
        target = staged / license_name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / license_name, target)
    provenance = {
        "repository": package["repository"], "commit": package["commit"],
        "version": package["version"], "license": package["license"],
        "platform": key, "asset_url": asset["url"], "asset_sha256": asset["sha256"],
        "executable": asset["executable"],
        "executable_sha256": file_digest(staged / asset["executable"]),
    }
    (staged / "source.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    return staged


def parse_arguments(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", choices=("hallmark", "codync", "all"), default="all")
    parser.add_argument("--target", choices=("codex", "claude", "both"), default="codex")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="Download and install; does not start agents or services.")
    mode.add_argument("--dry-run", action="store_true", help="Preview only (default); no network or filesystem changes.")
    parser.add_argument("--source-root", type=Path, default=Path(os.environ.get("AI_AGENT_SOURCE_ROOT", Path.home() / "src" / "ai-agent-sources")))
    parser.add_argument("--runtime-root", type=Path, default=Path.home() / ".local" / "share" / "ai-agent-portable" / "runtimes")
    parser.add_argument("--codex-home", type=Path, default=Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")))
    parser.add_argument("--claude-home", type=Path, default=Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude")))
    parser.add_argument("--manifest", type=Path, default=REPOSITORY_ROOT / "manifests" / "optional-sources.json")
    return parser.parse_args(argv)


def run(arguments: argparse.Namespace) -> None:
    # Validate every selected platform before creating source or destination paths.
    packages = load_packages(arguments.manifest, arguments.package)
    source_root, runtime_root = absolute(arguments.source_root), absolute(arguments.runtime_root)
    targets = ("codex", "claude") if arguments.target == "both" else (arguments.target,)
    homes = {"codex": absolute(arguments.codex_home), "claude": absolute(arguments.claude_home)}
    # Reject every used location before acquiring sources or creating directories.
    # Resolve links here as well: a path outside the checkout can point into it.
    check_outside_repository(source_root)
    if "hallmark" in packages:
        package = packages["hallmark"]
        for agent in targets:
            check_outside_repository(homes[agent] / "skills" / package["skill_name"])
            for license_name in package["license_files"]:
                check_outside_repository(homes[agent] / "licenses" / "hallmark" / package["commit"] / license_name)
    if "codync" in packages:
        check_outside_repository(runtime_root / "codync" / packages["codync"]["version"])
    copies = []
    sources = {}
    for name, package in packages.items():
        sources[name] = checkout_source(source_root, name, package, arguments.apply)
        source = sources[name]
        source_display = source_root / f"{name}-{package['commit']}"
        if name == "hallmark":
            for agent in targets:
                items = [(package["skill_path"], homes[agent] / "skills" / package["skill_name"])]
                items.extend((license_name, homes[agent] / "licenses" / name / package["commit"] / license_name) for license_name in package["license_files"])
                for relative, destination in items:
                    origin = source / relative if source else None
                    check_destination(origin, destination)
                    copies.append((origin, destination))
                    if not arguments.apply:
                        print(f"[dry-run] copy {source_display / relative} -> {destination}")
        else:
            destination = runtime_root / name / package["version"]
            check_path(destination)
            if destination.exists():
                inventory(destination)
                executable = destination / package["assets"][platform_key()]["executable"]
                if os.name != "nt" and executable.is_file() and not executable.stat().st_mode & stat.S_IXUSR:
                    raise InstallError(f"existing runtime executable has different permissions (owner execute bit missing); refusing to modify: {executable}")
            if not arguments.apply:
                asset = package["assets"][platform_key()]
                print(f"[dry-run] download and verify SHA256 {asset['sha256']}: {asset['url']}")
                print(f"[dry-run] compare/copy executable, licenses and source.json -> {destination}")
    if arguments.apply:
        if "codync" in packages:
            runtime_root.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(prefix=".codync-", dir=runtime_root) as temporary:
                package = packages["codync"]
                staged = stage_runtime(package, sources["codync"], Path(temporary))
                destination = runtime_root / "codync" / package["version"]
                check_destination(staged, destination)
                # No skills are installed until all targets and runtime contents pass.
                for source, target in copies:
                    install_copy(source, target)
                install_copy(staged, destination)
        else:
            for source, destination in copies:
                install_copy(source, destination)
    print(f"complete: optional {arguments.package} ({'apply' if arguments.apply else 'dry-run'}); no runtime or service started")


def main(argv: list[str] | None = None) -> int:
    if sys.version_info < (3, 10):
        print("error: Python 3.10+ is required", file=sys.stderr)
        return 1
    try:
        run(parse_arguments(argv))
        return 0
    except (InstallError, OSError, ValueError, KeyError, TypeError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
