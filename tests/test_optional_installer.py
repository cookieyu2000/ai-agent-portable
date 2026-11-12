import contextlib
import hashlib
import importlib.util
import io
import json
import os
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("install_optional", REPOSITORY_ROOT / "scripts" / "install_optional.py")
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class OptionalInstallerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.source_root = self.root / "sources"
        self.runtime_root = self.root / "runtimes"
        self.codex_home = self.root / "codex"
        self.claude_home = self.root / "claude"
        self.manifest_path = self.root / "optional-sources.json"
        self.manifest = {
            "schema_version": 1,
            "packages": {
                "hallmark": {
                    "kind": "skill", "repository": "https://github.com/Nutlope/hallmark.git",
                    "commit": "a" * 40, "skill_path": "skills/hallmark", "skill_name": "hallmark",
                    "license_files": ["LICENSE"],
                },
                "codync": {
                    "kind": "runtime", "repository": "https://github.com/leepokai/Codync.git",
                    "commit": "b" * 40, "version": "2.43.1", "license": "Apache-2.0",
                    "license_files": ["LICENSE"],
                    "assets": {"linux-x86_64": {
                        "url": "https://github.com/leepokai/Codync/releases/download/v2.43.1/codync-host.tar.gz",
                        "sha256": "c" * 64, "executable": "codync-host",
                        "archive_member": "codync-host", "format": "tar.gz",
                    }},
                },
            },
        }
        self.platform = mock.patch.object(installer, "platform_key", return_value="linux-x86_64")
        self.platform.start()
        self.addCleanup(self.platform.stop)

    def arguments(self, *extra):
        self.manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        return installer.parse_arguments([
            "--manifest", str(self.manifest_path), "--source-root", str(self.source_root),
            "--runtime-root", str(self.runtime_root), "--codex-home", str(self.codex_home),
            "--claude-home", str(self.claude_home), *extra,
        ])

    def run_installer(self, *extra):
        arguments = self.arguments(*extra)
        with contextlib.redirect_stdout(io.StringIO()):
            installer.run(arguments)

    def git(self, directory, *arguments):
        return subprocess.run(["git", "-C", str(directory), *arguments], check=True, text=True, capture_output=True).stdout.strip()

    def source(self, name):
        package = self.manifest["packages"][name]
        origin = self.root / f"fixture-{name}"
        origin.mkdir()
        self.git(origin, "init")
        (origin / "LICENSE").write_text(f"License for {name}\n", encoding="utf-8")
        if name == "hallmark":
            skill = origin / "skills" / "hallmark"
            skill.mkdir(parents=True)
            (skill / "SKILL.md").write_text("---\nname: hallmark\ndescription: Test skill\n---\n", encoding="utf-8")
            (skill / "themes").mkdir()
            (skill / "themes" / "example.md").write_text("Theme fixture\n", encoding="utf-8")
        self.git(origin, "add", ".")
        self.git(origin, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-m", "fixture")
        package["commit"] = self.git(origin, "rev-parse", "HEAD")
        self.source_root.mkdir(exist_ok=True)
        checkout = self.source_root / f"{name}-{package['commit']}"
        origin.rename(checkout)
        return checkout

    def archive(self, members=None):
        archive = self.root / "fixture.tar.gz"
        with tarfile.open(archive, "w:gz") as bundle:
            for name, content, kind in members or [("./codync-host", b"fixture executable", tarfile.REGTYPE)]:
                member = tarfile.TarInfo(name)
                member.type = kind
                member.size = len(content) if kind == tarfile.REGTYPE else 0
                member.linkname = "codync-host" if kind == tarfile.SYMTYPE else ""
                bundle.addfile(member, io.BytesIO(content) if member.isfile() else None)
        asset = self.manifest["packages"]["codync"]["assets"]["linux-x86_64"]
        asset["sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
        return archive

    def download_fixture(self, archive):
        def copy(_url, destination):
            with destination.open("xb") as output:
                output.write(archive.read_bytes())
        return mock.patch.object(installer, "download", side_effect=copy)

    def test_default_dry_run_has_no_network_writes_or_directories(self):
        arguments = self.arguments()
        before = sorted(path.relative_to(self.root) for path in self.root.rglob("*"))
        with mock.patch.object(installer, "download", side_effect=AssertionError("network")), \
             mock.patch.object(installer, "git", side_effect=AssertionError("git")), \
             mock.patch.object(Path, "mkdir", side_effect=AssertionError("mkdir")), \
             mock.patch.object(Path, "write_text", side_effect=AssertionError("write")), \
             contextlib.redirect_stdout(io.StringIO()):
            installer.run(arguments)
        self.assertEqual(before, sorted(path.relative_to(self.root) for path in self.root.rglob("*")))

    def test_repository_destinations_are_refused_before_any_side_effect(self):
        portable = self.root / "portable"
        portable.mkdir()
        cases = [
            ("--source-root", portable, "--package", "hallmark"),
            ("--runtime-root", portable / "runtimes", "--package", "codync"),
            ("--codex-home", portable / "profile", "--package", "hallmark"),
            ("--claude-home", portable / "profile", "--target", "both", "--package", "hallmark"),
        ]
        for case in cases:
            for mode in ("--dry-run", "--apply"):
                with self.subTest(case=case, mode=mode):
                    arguments = self.arguments(*(str(value) for value in case), mode)
                    before = sorted(path.relative_to(self.root) for path in self.root.rglob("*"))
                    with mock.patch.object(installer, "REPOSITORY_ROOT", portable), \
                         mock.patch.object(installer, "download", side_effect=AssertionError("network")), \
                         mock.patch.object(installer, "git", side_effect=AssertionError("git")), \
                         mock.patch.object(Path, "mkdir", side_effect=AssertionError("mkdir")), \
                         self.assertRaisesRegex(installer.InstallError, "outside the portable repository"):
                        installer.run(arguments)
                    self.assertEqual(before, sorted(path.relative_to(self.root) for path in self.root.rglob("*")))

    @unittest.skipUnless(hasattr(os, "symlink"), "symlink unavailable")
    def test_repository_destination_through_link_is_refused_before_source_fetch(self):
        portable = self.root / "portable"
        portable.mkdir()
        alias = self.root / "outside-alias"
        try:
            alias.symlink_to(portable, target_is_directory=True)
        except OSError:
            self.skipTest("symlink permission unavailable")
        arguments = self.arguments("--package", "codync", "--runtime-root", str(alias / "runtimes"), "--apply")
        with mock.patch.object(installer, "REPOSITORY_ROOT", portable), \
             mock.patch.object(installer, "git", side_effect=AssertionError("git")), \
             mock.patch.object(installer, "download", side_effect=AssertionError("network")), \
             self.assertRaisesRegex(installer.InstallError, "outside the portable repository"):
            installer.run(arguments)
        self.assertEqual([], list(portable.iterdir()))
        self.assertFalse(self.source_root.exists())

    def test_unused_agent_or_runtime_path_does_not_block_other_package(self):
        portable = self.root / "portable"
        portable.mkdir()
        with mock.patch.object(installer, "REPOSITORY_ROOT", portable):
            self.run_installer("--package", "codync", "--codex-home", str(portable), "--claude-home", str(portable))
            self.run_installer("--package", "hallmark", "--runtime-root", str(portable), "--claude-home", str(portable))

    def test_hallmark_both_copies_entire_skill_and_license_idempotently(self):
        source = self.source("hallmark")
        self.run_installer("--package", "hallmark", "--target", "both", "--apply")
        installed = self.codex_home / "skills" / "hallmark" / "SKILL.md"
        timestamp = installed.stat().st_mtime_ns
        self.run_installer("--package", "hallmark", "--target", "both", "--apply")
        self.assertEqual(timestamp, installed.stat().st_mtime_ns)
        for home in (self.codex_home, self.claude_home):
            self.assertEqual(installer.inventory(source / "skills" / "hallmark"), installer.inventory(home / "skills" / "hallmark"))
            self.assertEqual((source / "LICENSE").read_bytes(), (home / "licenses" / "hallmark" / self.manifest["packages"]["hallmark"]["commit"] / "LICENSE").read_bytes())
            self.assertFalse((home / "settings.json").exists())

    def test_second_target_conflict_does_not_install_first(self):
        self.source("hallmark")
        conflict = self.claude_home / "skills" / "hallmark"
        conflict.mkdir(parents=True)
        (conflict / "SKILL.md").write_text("user content", encoding="utf-8")
        with self.assertRaisesRegex(installer.InstallError, "refusing to overwrite"):
            self.run_installer("--package", "hallmark", "--target", "both", "--apply")
        self.assertFalse(self.codex_home.exists())
        self.assertEqual("user content", (conflict / "SKILL.md").read_text())

    @unittest.skipUnless(hasattr(os, "symlink"), "symlink unavailable")
    def test_existing_symlink_is_refused(self):
        source = self.source("hallmark")
        destination = self.codex_home / "skills" / "hallmark"
        destination.parent.mkdir(parents=True)
        try:
            destination.symlink_to(source / "skills" / "hallmark", target_is_directory=True)
        except OSError:
            self.skipTest("symlink permission unavailable")
        with self.assertRaisesRegex(installer.InstallError, "refusing symlink"):
            self.run_installer("--package", "hallmark", "--apply")

    def test_dirty_source_refused_even_for_untracked_files(self):
        source = self.source("hallmark")
        (source / "skills" / "hallmark" / "extra.txt").write_text("untracked", encoding="utf-8")
        with self.assertRaisesRegex(installer.InstallError, "dirty"):
            self.run_installer("--package", "hallmark", "--apply")
        self.assertFalse(self.codex_home.exists())

    def test_wrong_head_refused_without_modifying_source(self):
        source = self.source("hallmark")
        (source / "LICENSE").write_text("new license", encoding="utf-8")
        self.git(source, "add", ".")
        self.git(source, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-m", "new commit")
        current_head = self.git(source, "rev-parse", "HEAD")
        with self.assertRaisesRegex(installer.InstallError, "source pin mismatch"):
            self.run_installer("--package", "hallmark", "--apply")
        self.assertEqual(current_head, self.git(source, "rev-parse", "HEAD"))
        self.assertFalse(self.codex_home.exists())

    def test_sha_mismatch_does_not_install_runtime_or_skill(self):
        self.source("hallmark")
        self.source("codync")
        archive = self.archive()
        self.manifest["packages"]["codync"]["assets"]["linux-x86_64"]["sha256"] = "0" * 64
        with self.download_fixture(archive), self.assertRaisesRegex(installer.InstallError, "SHA256 mismatch"):
            self.run_installer("--apply")
        self.assertFalse(self.codex_home.exists())
        self.assertFalse((self.runtime_root / "codync").exists())
        self.assertEqual([], list(self.runtime_root.iterdir()))

    def test_runtime_installs_verified_binary_license_and_provenance_without_running(self):
        self.source("codync")
        archive = self.archive([
            ("./codync-host", b"fixture executable", tarfile.REGTYPE),
            ("unneeded.txt", b"ignored content", tarfile.REGTYPE),
        ])
        with self.download_fixture(archive):
            self.run_installer("--package", "codync", "--apply")
            executable = self.runtime_root / "codync" / "2.43.1" / "codync-host"
            timestamp = executable.stat().st_mtime_ns
            self.run_installer("--package", "codync", "--apply")
        self.assertEqual(timestamp, executable.stat().st_mtime_ns)
        self.assertEqual(b"fixture executable", executable.read_bytes())
        self.assertEqual({"codync-host", "LICENSE", "source.json"}, {p.name for p in executable.parent.iterdir()})
        provenance = json.loads((executable.parent / "source.json").read_text())
        self.assertEqual(self.manifest["packages"]["codync"]["commit"], provenance["commit"])
        self.assertEqual(installer.file_digest(executable), provenance["executable_sha256"])
        self.assertFalse(self.codex_home.exists())

    def test_runtime_modified_content_is_not_overwritten(self):
        self.source("codync")
        archive = self.archive()
        with self.download_fixture(archive):
            self.run_installer("--package", "codync", "--apply")
            executable = self.runtime_root / "codync" / "2.43.1" / "codync-host"
            executable.write_bytes(b"locally edited")
            with self.assertRaisesRegex(installer.InstallError, "refusing to overwrite"):
                self.run_installer("--package", "codync", "--apply")
        self.assertEqual(b"locally edited", executable.read_bytes())

    @unittest.skipIf(os.name == "nt", "POSIX executable permissions")
    def test_runtime_missing_execute_permission_is_refused(self):
        self.source("codync")
        archive = self.archive()
        with self.download_fixture(archive):
            self.run_installer("--package", "codync", "--apply")
            executable = self.runtime_root / "codync" / "2.43.1" / "codync-host"
            executable.chmod(0o644)
            with self.assertRaisesRegex(installer.InstallError, "owner execute bit missing"):
                self.run_installer("--package", "codync", "--apply")
        self.assertEqual(0o644, executable.stat().st_mode & 0o777)

    def test_tar_traversal_is_rejected(self):
        self.source("codync")
        archive = self.archive([
            ("codync-host", b"fixture", tarfile.REGTYPE),
            ("../../outside", b"escape", tarfile.REGTYPE),
        ])
        with self.download_fixture(archive), self.assertRaisesRegex(installer.InstallError, "unsafe manifest path"):
            self.run_installer("--package", "codync", "--apply")
        self.assertFalse((self.root / "outside").exists())
        self.assertFalse((self.runtime_root / "codync").exists())

    def test_tar_symlink_is_rejected(self):
        self.source("codync")
        archive = self.archive([("codync-host", b"", tarfile.SYMTYPE)])
        with self.download_fixture(archive), self.assertRaisesRegex(installer.InstallError, "unsafe archive member"):
            self.run_installer("--package", "codync", "--apply")
        self.assertFalse((self.runtime_root / "codync").exists())

    def test_unsupported_platform_stops_all_before_writing(self):
        with mock.patch.object(installer, "platform_key", return_value="windows-x86_64"):
            for mode in ("--dry-run", "--apply"):
                with self.subTest(mode=mode), self.assertRaisesRegex(installer.InstallError, "no pinned host asset.*WSL"):
                    self.run_installer(mode)
        self.assertFalse(self.source_root.exists())
        self.assertFalse(self.codex_home.exists())
        self.assertFalse(self.runtime_root.exists())

    def test_source_fetch_is_pinned_and_shallow(self):
        source = self.source("hallmark")
        fixture = self.root / "origin"
        source.rename(fixture)
        real_git = installer.git
        commands = []
        def local_git(*arguments):
            commands.append(arguments)
            args = list(arguments)
            if "fetch" in args:
                args[args.index("--") + 1] = str(fixture)
            return real_git(*args)
        with mock.patch.object(installer, "git", side_effect=local_git):
            self.run_installer("--package", "hallmark", "--apply")
        fetch = next(command for command in commands if "fetch" in command)
        self.assertEqual(("--depth", "1", "--"), fetch[3:6])
        self.assertEqual(self.manifest["packages"]["hallmark"]["commit"], fetch[-1])
        self.assertEqual(self.manifest["packages"]["hallmark"]["commit"], self.git(source, "rev-parse", "HEAD"))

    def test_repository_manifest_validates_all_published_platforms(self):
        manifest_path = REPOSITORY_ROOT / "manifests" / "optional-sources.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual({"hallmark", "codync"}, set(manifest["packages"]))
        for key, asset in manifest["packages"]["codync"]["assets"].items():
            with self.subTest(platform=key), mock.patch.object(installer, "platform_key", return_value=key):
                self.assertEqual({"hallmark", "codync"}, set(installer.load_packages(manifest_path, "all")))
                self.assertRegex(asset["sha256"], r"^[0-9a-f]{64}$")

    def test_old_python_reports_clear_requirement(self):
        output = io.StringIO()
        with mock.patch.object(installer.sys, "version_info", (3, 9)), contextlib.redirect_stderr(output):
            self.assertEqual(1, installer.main([]))
        self.assertIn("Python 3.10+ is required", output.getvalue())


if __name__ == "__main__":
    unittest.main()
