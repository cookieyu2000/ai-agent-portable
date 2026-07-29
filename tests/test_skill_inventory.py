import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
INVENTORY_SCRIPT = REPOSITORY_ROOT / "scripts" / "skill_inventory.py"


def write_skill(
    skill_directory: Path,
    name: str,
    description: str,
) -> None:
    skill_directory.mkdir(parents=True, exist_ok=True)
    (skill_directory / "SKILL.md").write_text(
        "\n".join(
            [
                "---",
                f"name: {name}",
                f'description: "{description}"',
                "---",
                "",
                f"# {name}",
                "",
            ]
        ),
        encoding="utf-8",
    )


def write_claude_command(
    command_file: Path,
    description: str,
) -> None:
    command_file.parent.mkdir(parents=True, exist_ok=True)
    command_file.write_text(
        "\n".join(
            [
                "---",
                f"description: {description}",
                "---",
                "",
                "Run the command.",
                "",
            ]
        ),
        encoding="utf-8",
    )


class SkillInventoryCliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.codex_home = Path(self.temporary_directory.name) / ".codex"
        self.claude_home = Path(self.temporary_directory.name) / ".claude"

        write_skill(
            self.codex_home / "skills" / "alpha",
            "alpha",
            "First skill.",
        )
        write_skill(
            self.codex_home / "skills" / "pipe-skill",
            "pipe-skill",
            "Explains A | B.",
        )
        write_skill(
            self.codex_home
            / "plugins"
            / "cache"
            / "example-marketplace"
            / "example-plugin"
            / "1.0.0"
            / "skills"
            / "alpha",
            "alpha",
            "First skill.",
        )
        write_skill(
            self.claude_home
            / "plugins"
            / "cache"
            / "example-marketplace"
            / "example-plugin"
            / "2.0.0"
            / "skills"
            / "alpha",
            "alpha",
            "First skill.",
        )
        write_skill(
            self.claude_home / "skills" / "claude-only",
            "claude-only",
            "Claude-only skill.",
        )
        write_claude_command(
            self.claude_home
            / "plugins"
            / "cache"
            / "example-marketplace"
            / "example-plugin"
            / "2.0.0"
            / ".claude"
            / "commands"
            / "plan.md",
            "Plan work.",
        )

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def run_inventory(
        self,
        output_format: str,
        platform: str = "both",
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(INVENTORY_SCRIPT),
                "--platform",
                platform,
                "--codex-home",
                str(self.codex_home),
                "--claude-home",
                str(self.claude_home),
                "--format",
                output_format,
            ],
            check=False,
            text=True,
            capture_output=True,
        )

    def test_json_deduplicates_names_and_merges_sources(self) -> None:
        result = self.run_inventory("json")

        self.assertEqual(result.returncode, 0, result.stderr)
        inventory = json.loads(result.stdout)
        self.assertEqual(inventory["count"], 4)
        self.assertEqual(
            [skill["name"] for skill in inventory["skills"]],
            ["alpha", "claude-only", "pipe-skill", "plan"],
        )
        self.assertEqual(
            inventory["skills"][0]["sources"],
            [
                "claude-plugin:example-marketplace/example-plugin",
                "codex-plugin:example-marketplace/example-plugin",
                "codex:user",
            ],
        )
        self.assertEqual(inventory["skills"][0]["platforms"], ["claude", "codex"])

    def test_platform_filter_limits_inventory(self) -> None:
        codex_result = self.run_inventory("json", platform="codex")
        claude_result = self.run_inventory("json", platform="claude")

        self.assertEqual(codex_result.returncode, 0, codex_result.stderr)
        self.assertEqual(claude_result.returncode, 0, claude_result.stderr)
        self.assertEqual(json.loads(codex_result.stdout)["count"], 2)
        self.assertEqual(json.loads(claude_result.stdout)["count"], 3)

    def test_markdown_is_public_safe_and_escapes_table_pipes(self) -> None:
        result = self.run_inventory("markdown")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("# Codex and Claude Skill Inventory", result.stdout)
        self.assertIn("Total unique skills: **4**", result.stdout)
        self.assertIn("Explains A \\| B.", result.stdout)
        self.assertNotIn(str(self.codex_home), result.stdout)
        self.assertNotIn(str(self.claude_home), result.stdout)
        self.assertIn(
            "A filesystem inventory can include cached or internal skills",
            result.stdout,
        )

    def test_table_shows_count_name_source_and_description(self) -> None:
        result = self.run_inventory("table")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Skills found: 4", result.stdout)
        self.assertIn("alpha", result.stdout)
        self.assertIn("claude, codex", result.stdout)
        self.assertIn("codex:user", result.stdout)
        self.assertIn("First skill.", result.stdout)


if __name__ == "__main__":
    unittest.main()
