#!/usr/bin/env python3
"""Read Codex plugin state and validate the pinned local ADHD plugin."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


HUGGING_FACE_PLUGIN = "hugging-face@openai-curated"
ADHD_PLUGIN = "i-have-adhd@i-have-adhd"


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as error:
        raise ValueError(f"cannot read local plugin manifest {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"invalid local plugin manifest: {path}")
    return value


def validate_local(source: Path) -> None:
    marketplace = read_json(source / ".claude-plugin/marketplace.json")
    entries = marketplace.get("plugins")
    if marketplace.get("name") != "i-have-adhd" or not isinstance(entries, list):
        raise ValueError(f"invalid i-have-adhd marketplace manifest: {source}")
    plugins = [entry for entry in entries if isinstance(entry, dict)
               and entry.get("name") == "i-have-adhd"]
    if len(plugins) != 1 or plugins[0].get("source") != "./":
        raise ValueError(f"i-have-adhd marketplace must use its pinned local plugin: {source}")
    plugin = read_json(source / ".codex-plugin/plugin.json")
    if plugin.get("name") != "i-have-adhd" or plugin.get("skills") != "./skills/":
        raise ValueError(f"invalid i-have-adhd plugin manifest: {source}")
    if not (source / "skills/i-have-adhd/SKILL.md").is_file():
        raise ValueError(f"missing i-have-adhd plugin skill: {source}")


def cli_json(raw: str, command: str) -> dict:
    try:
        value = json.loads(raw)
    except ValueError as error:
        raise ValueError(f"invalid JSON from {command}; check Codex CLI compatibility") from error
    if not isinstance(value, dict):
        raise ValueError(f"invalid JSON object from {command}")
    return value


def identifier(value: object) -> bool:
    return isinstance(value, str) and bool(value) and not any(c.isspace() for c in value)


def plugin_entries(snapshot: dict, key: str) -> list[dict]:
    entries = snapshot.get(key)
    if not isinstance(entries, list):
        raise ValueError(f"invalid Codex plugin JSON: expected an {key} array")
    for entry in entries:
        if (not isinstance(entry, dict) or not identifier(entry.get("pluginId"))
                or entry["pluginId"].count("@") != 1
                or not all(entry["pluginId"].split("@"))
                or not isinstance(entry.get("installed"), bool)):
            raise ValueError(f"invalid Codex plugin JSON entry in {key}")
    return entries


def preflight(args: argparse.Namespace) -> None:
    # Bash resolves CLI wrappers (including Windows shims). A literal record
    # separator cannot occur in valid JSON, so no temporary files are needed.
    records = sys.stdin.buffer.read().decode("utf-8").split("\x1e")
    if len(records) != 2:
        raise ValueError("expected plugin and marketplace JSON snapshots on stdin")
    snapshot = cli_json(records[0], "codex plugin list --available --json")
    installed = {entry["pluginId"] for entry in plugin_entries(snapshot, "installed")
                 if entry["installed"] is True}
    available = {entry["pluginId"] for entry in plugin_entries(snapshot, "available")}
    marketplace_snapshot = cli_json(records[1], "codex plugin marketplace list --json")
    marketplaces = marketplace_snapshot.get("marketplaces")
    if not isinstance(marketplaces, list):
        raise ValueError("invalid Codex marketplace JSON: expected a marketplaces array")
    for entry in marketplaces:
        if not isinstance(entry, dict) or not identifier(entry.get("name")):
            raise ValueError("invalid Codex marketplace JSON entry")
    marketplace_names = {entry["name"] for entry in marketplaces}

    if not re.fullmatch(r"github@[a-zA-Z0-9][a-zA-Z0-9._-]*", args.github_plugin):
        raise ValueError("--github-plugin requires an exact github@marketplace ID")
    selected = [args.github_plugin]
    if not args.skip_hugging_face:
        selected.append(HUGGING_FACE_PLUGIN)
    missing = [plugin for plugin in selected if plugin not in installed
               and (plugin not in available or plugin.split("@")[1] not in marketplace_names)]
    if missing:
        hint = (" Hugging Face may be skipped with --skip-hugging-face."
                if HUGGING_FACE_PLUGIN in missing else "")
        raise ValueError("plugin unavailable: " + ", ".join(missing)
                         + "; verify the exact plugin ID and marketplace using "
                         "codex plugin list --available --json and codex plugin marketplace list --json."
                         + hint + " No installation was started.")

    if not args.skip_adhd:
        for entry in marketplaces:
            if entry["name"] == "i-have-adhd":
                root = entry.get("root")
                if not isinstance(root, str) or Path(root).resolve() != args.adhd_source.resolve():
                    raise ValueError("existing i-have-adhd marketplace points elsewhere; "
                                     "compare its root with the pinned source before retrying")
                if ADHD_PLUGIN not in installed and ADHD_PLUGIN not in available:
                    raise ValueError(f"plugin unavailable: {ADHD_PLUGIN} in the existing marketplace")
        if args.adhd_source.exists() or args.adhd_source.is_symlink():
            validate_local(args.adhd_source)

    # Only validated identifiers reach the shell; never evaluate CLI output as code.
    records = [f"plugin\t{plugin}\n" for plugin in sorted(installed)]
    records.extend(f"marketplace\t{name}\n" for name in sorted(marketplace_names))
    # Native Windows Python would otherwise translate newlines to CRLF, which
    # Bash would preserve in the identifiers it reads.
    sys.stdout.buffer.write("".join(records).encode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("preflight")
    check.add_argument("--skip-hugging-face", action="store_true")
    check.add_argument("--github-plugin", default="github@openai-curated")
    check.add_argument("--skip-adhd", action="store_true")
    check.add_argument("--adhd-source", required=True, type=Path)
    local = commands.add_parser("validate-local")
    local.add_argument("source", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "preflight":
            preflight(args)
        else:
            validate_local(args.source)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
