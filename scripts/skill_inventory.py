#!/usr/bin/env python3
"""List Codex and Claude skills found in user and plugin-cache directories."""

from __future__ import annotations

import argparse
import ast
import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


@dataclass
class SkillRecord:
    name: str
    description: str
    platforms: set[str] = field(default_factory=set)
    sources: set[str] = field(default_factory=set)


def parse_scalar(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        try:
            parsed = ast.literal_eval(value)
        except (SyntaxError, ValueError):
            return value[1:-1]
        return str(parsed)
    return value


def frontmatter_value(lines: list[str], key: str) -> str:
    prefix = f"{key}:"
    for index, line in enumerate(lines):
        if not line.startswith(prefix):
            continue

        value = line[len(prefix) :].strip()
        if value not in {"|", "|-", ">", ">-"}:
            return parse_scalar(value)

        continuation: list[str] = []
        for following_line in lines[index + 1 :]:
            if following_line and not following_line[0].isspace():
                break
            continuation.append(following_line.strip())
        separator = "\n" if value.startswith("|") else " "
        return separator.join(part for part in continuation if part)
    return ""


def parse_skill(skill_file: Path) -> tuple[str, str] | None:
    try:
        lines = skill_file.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return None

    if not lines or lines[0].strip() != "---":
        return None

    try:
        closing_index = next(
            index
            for index, line in enumerate(lines[1:], start=1)
            if line.strip() == "---"
        )
    except StopIteration:
        return None

    frontmatter = lines[1:closing_index]
    name = frontmatter_value(frontmatter, "name")
    if not name:
        return None
    return name, frontmatter_value(frontmatter, "description")


def parse_claude_command(command_file: Path) -> tuple[str, str] | None:
    try:
        lines = command_file.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return None

    if not lines or lines[0].strip() != "---":
        return None
    try:
        closing_index = next(
            index
            for index, line in enumerate(lines[1:], start=1)
            if line.strip() == "---"
        )
    except StopIteration:
        return None

    description = frontmatter_value(lines[1:closing_index], "description")
    return command_file.stem, description


def source_label(
    skill_file: Path,
    scan_root: Path,
    root_kind: str,
    platform: str,
) -> str:
    relative_parts = skill_file.relative_to(scan_root).parts
    if root_kind == "user":
        category = "system" if relative_parts[0] == ".system" else "user"
        return f"{platform}:{category}"

    if len(relative_parts) >= 2:
        return f"{platform}-plugin:{relative_parts[0]}/{relative_parts[1]}"
    if relative_parts:
        return f"{platform}-plugin:{relative_parts[0]}"
    return f"{platform}-plugin-cache"


def skill_files(scan_root: Path) -> Iterable[Path]:
    if not scan_root.is_dir():
        return

    visited_directories: set[Path] = set()
    for current_directory, directories, files in os.walk(
        scan_root,
        followlinks=True,
    ):
        directories[:] = [
            directory
            for directory in directories
            if directory not in {".git", "__pycache__"}
        ]

        resolved_directory = Path(current_directory).resolve()
        if resolved_directory in visited_directories:
            directories.clear()
            continue
        visited_directories.add(resolved_directory)

        if "SKILL.md" in files:
            yield Path(current_directory) / "SKILL.md"


def claude_command_files(scan_root: Path, root_kind: str) -> Iterable[Path]:
    if not scan_root.is_dir():
        return

    if root_kind == "user":
        command_root = scan_root.parent / "commands"
        if command_root.is_dir():
            yield from sorted(command_root.rglob("*.md"))
        return

    yield from sorted(scan_root.glob("*/*/*/.claude/commands/*.md"))


def merge_record(
    records: dict[str, SkillRecord],
    name: str,
    description: str,
    platform: str,
    source: str,
) -> None:
    record = records.setdefault(
        name,
        SkillRecord(name=name, description=description),
    )
    if len(description) > len(record.description):
        record.description = description
    record.platforms.add(platform)
    record.sources.add(source)


def discover_skills(
    codex_home: Path,
    claude_home: Path,
    platform: str,
) -> list[SkillRecord]:
    records: dict[str, SkillRecord] = {}
    scan_roots: list[tuple[Path, str, str]] = []
    if platform in {"codex", "both"}:
        scan_roots.extend(
            [
                (codex_home / "skills", "user", "codex"),
                (codex_home / "plugins" / "cache", "plugin", "codex"),
            ]
        )
    if platform in {"claude", "both"}:
        scan_roots.extend(
            [
                (claude_home / "skills", "user", "claude"),
                (claude_home / "plugins" / "cache", "plugin", "claude"),
            ]
        )

    for scan_root, root_kind, current_platform in scan_roots:
        for skill_file in skill_files(scan_root):
            parsed_skill = parse_skill(skill_file)
            if parsed_skill is None:
                continue

            name, description = parsed_skill
            merge_record(
                records,
                name,
                description,
                current_platform,
                source_label(
                    skill_file,
                    scan_root,
                    root_kind,
                    current_platform,
                ),
            )

        if current_platform != "claude":
            continue
        for command_file in claude_command_files(scan_root, root_kind):
            parsed_command = parse_claude_command(command_file)
            if parsed_command is None:
                continue
            name, description = parsed_command
            source = source_label(
                command_file,
                scan_root,
                root_kind,
                current_platform,
            ).replace("claude-plugin:", "claude-command:", 1)
            if root_kind == "user":
                source = "claude:user-command"
            merge_record(
                records,
                name,
                description,
                current_platform,
                source,
            )

    return sorted(records.values(), key=lambda record: record.name.casefold())


def truncated(value: str, maximum_length: int = 100) -> str:
    single_line = " ".join(value.split())
    if len(single_line) <= maximum_length:
        return single_line
    return f"{single_line[: maximum_length - 1]}…"


def render_table(skills: list[SkillRecord], platform: str) -> str:
    rows = [
        (
            str(index),
            skill.name,
            ", ".join(sorted(skill.platforms)),
            ", ".join(sorted(skill.sources)),
            truncated(skill.description),
        )
        for index, skill in enumerate(skills, start=1)
    ]
    headers = ("#", "Skill", "Platform", "Source", "Description")
    widths = [
        max(len(headers[column]), *(len(row[column]) for row in rows))
        if rows
        else len(headers[column])
        for column in range(len(headers))
    ]

    output = [f"Skills found: {len(skills)}"]
    output.append(
        "  ".join(
            header.ljust(widths[index])
            for index, header in enumerate(headers)
        )
    )
    output.append("  ".join("-" * width for width in widths))
    output.extend(
        "  ".join(value.ljust(widths[index]) for index, value in enumerate(row))
        for row in rows
    )
    return "\n".join(output) + "\n"


def markdown_cell(value: str) -> str:
    return " ".join(value.split()).replace("\\", "\\\\").replace("|", "\\|")


def inventory_title(platform: str) -> str:
    if platform == "both":
        return "Codex and Claude Skill Inventory"
    return f"{platform.title()} Skill Inventory"


def render_markdown(skills: list[SkillRecord], platform: str) -> str:
    output = [
        f"# {inventory_title(platform)}",
        "",
        f"Total unique skills: **{len(skills)}**",
        "",
        "> A filesystem inventory can include cached or internal skills that are",
        "> not exposed to every agent session.",
        "",
        "| # | Skill | Platform | Source | Description |",
        "|---:|---|---|---|---|",
    ]
    output.extend(
        "| {index} | `{name}` | {platforms} | {sources} | {description} |".format(
            index=index,
            name=markdown_cell(skill.name),
            platforms=markdown_cell(", ".join(sorted(skill.platforms))),
            sources=markdown_cell(", ".join(sorted(skill.sources))),
            description=markdown_cell(skill.description),
        )
        for index, skill in enumerate(skills, start=1)
    )
    return "\n".join(output) + "\n"


def render_json(skills: list[SkillRecord], platform: str) -> str:
    payload = {
        "count": len(skills),
        "platform": platform,
        "skills": [
            {
                "name": skill.name,
                "description": skill.description,
                "platforms": sorted(skill.platforms),
                "sources": sorted(skill.sources),
            }
            for skill in skills
        ],
    }
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="List Codex and Claude skills from their local directories."
    )
    parser.add_argument(
        "--platform",
        choices=("codex", "claude", "both"),
        default="both",
        help="Agent platform to inspect (default: both).",
    )
    parser.add_argument(
        "--codex-home",
        type=Path,
        default=Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")),
        help="Codex configuration directory (default: CODEX_HOME or ~/.codex).",
    )
    parser.add_argument(
        "--claude-home",
        type=Path,
        default=Path(
            os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude")
        ),
        help=(
            "Claude configuration directory "
            "(default: CLAUDE_CONFIG_DIR or ~/.claude)."
        ),
    )
    parser.add_argument(
        "--format",
        choices=("table", "markdown", "json"),
        default="table",
        help="Output format (default: table).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Write output to this file instead of stdout.",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    skills = discover_skills(
        arguments.codex_home.expanduser(),
        arguments.claude_home.expanduser(),
        arguments.platform,
    )
    renderers = {
        "table": render_table,
        "markdown": render_markdown,
        "json": render_json,
    }
    output = renderers[arguments.format](skills, arguments.platform)

    if arguments.output is None:
        print(output, end="")
    else:
        arguments.output.write_text(output, encoding="utf-8")
        print(
            f"Wrote {len(skills)} skills to {arguments.output}",
            file=os.sys.stderr,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
