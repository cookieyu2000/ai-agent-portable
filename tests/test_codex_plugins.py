import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
GITHUB = "github@openai-curated"
HUGGING_FACE = "hugging-face@openai-curated"
ADHD = "i-have-adhd@i-have-adhd"


FAKE_CODEX = r'''
import json
import os
import sys
from pathlib import Path

args = sys.argv[1:]
control = json.loads(Path(os.environ["PLUGIN_TEST_CONTROL"]).read_text())
state_path = Path(os.environ["PLUGIN_TEST_STATE"])
state = json.loads(state_path.read_text())
mutation = args[:2] == ["plugin", "add"] or args[:3] == ["plugin", "marketplace", "add"]
with Path(os.environ["PLUGIN_TEST_EVENTS"]).open("a") as stream:
    stream.write(json.dumps({"command": "codex", "args": args, "mutation": mutation}) + "\n")

def entry(plugin_id, installed):
    name, marketplace = plugin_id.split("@", 1)
    return {"pluginId": plugin_id, "name": name, "marketplaceName": marketplace,
            "installed": installed, "enabled": installed}

available = list(control.get("available", []))
if "i-have-adhd" in state["marketplaces"]:
    available.append("i-have-adhd@i-have-adhd")
if args[:2] == ["plugin", "list"]:
    if control.get("list_failure"):
        print("fixture catalog query failed", file=sys.stderr)
        sys.exit(7)
    if "list_output" in control:
        print(control["list_output"])
    else:
        print(json.dumps({"installed": [entry(p, True) for p in state["installed"]],
                          "available": [entry(p, False) for p in available]}, separators=(",", ":")))
elif args[:3] == ["plugin", "marketplace", "list"]:
    if control.get("marketplace_failure"):
        print("fixture marketplace query failed", file=sys.stderr)
        sys.exit(8)
    if "marketplace_output" in control:
        print(control["marketplace_output"])
    else:
        names = control.get("marketplaces", ["openai-curated"]) + state["marketplaces"]
        roots = control.get("marketplace_roots", {})
        print(json.dumps({"marketplaces": [{"name": name,
                                            "root": roots.get(name, str(Path(os.environ["AI_AGENT_SOURCE_ROOT"]) / name)
                                            if name == "i-have-adhd" else "/fixture/" + name)}
                                           for name in names]}, separators=(",", ":")))
elif args[:2] == ["plugin", "add"] and len(args) == 3:
    plugin_id = args[2]
    if plugin_id == control.get("fail_plugin"):
        print("fixture plugin installation failed: " + plugin_id, file=sys.stderr)
        sys.exit(9)
    if plugin_id not in available:
        print("fixture unknown plugin: " + plugin_id, file=sys.stderr)
        sys.exit(10)
    if plugin_id in state["installed"]:
        print("fixture refused duplicate plugin install: " + plugin_id, file=sys.stderr)
        sys.exit(11)
    state["installed"].append(plugin_id)
    state_path.write_text(json.dumps(state))
elif args[:3] == ["plugin", "marketplace", "add"] and len(args) == 4:
    root = Path(args[3])
    manifest = json.loads((root / ".claude-plugin" / "marketplace.json").read_text())
    name = manifest["name"]
    if name in state["marketplaces"]:
        print("fixture refused duplicate marketplace registration", file=sys.stderr)
        sys.exit(12)
    state["marketplaces"].append(name)
    state_path.write_text(json.dumps(state))
else:
    print("unexpected fake codex invocation: " + repr(args), file=sys.stderr)
    sys.exit(13)
'''


FAKE_GIT = r'''
import json
import os
import shutil
import sys
from pathlib import Path

args = sys.argv[1:]
with Path(os.environ["PLUGIN_TEST_EVENTS"]).open("a") as stream:
    stream.write(json.dumps({"command": "git", "args": args,
                             "mutation": args[:1] == ["clone"]}) + "\n")
if args[:1] == ["clone"] and len(args) == 3:
    name = args[1].rsplit("/", 1)[-1]
    if name.endswith(".git"):
        name = name[:-4]
    shutil.copytree(Path(os.environ["PLUGIN_TEST_FIXTURES"]) / name, args[2], dirs_exist_ok=True)
elif args[:1] == ["-C"] and args[2:] == ["rev-parse", "HEAD"]:
    print((Path(args[1]) / ".git" / "HEAD").read_text().strip())
elif args[:1] == ["-C"] and args[2:4] == ["checkout", "--detach"]:
    if (Path(args[1]) / ".git" / "HEAD").read_text().strip() != args[4]:
        sys.exit(14)
elif args[:1] == ["-C"] and args[2:4] == ["diff", "--quiet"]:
    pass
else:
    print("unexpected fake git invocation: " + repr(args), file=sys.stderr)
    sys.exit(15)
'''


class CodexPluginBootstrapTest(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.home = self.root / "home"
        self.codex_home = self.root / "codex"
        self.sources = self.root / "sources"
        self.fixtures = self.root / "fixtures"
        self.control_path = self.root / "control.json"
        self.state_path = self.root / "state.json"
        self.events_path = self.root / "events.jsonl"
        self.control = {"available": [GITHUB, HUGGING_FACE]}
        self.state_path.write_text(json.dumps({"installed": [], "marketplaces": []}))
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, script in [("codex", FAKE_CODEX), ("git", FAKE_GIT)]:
            path = self.bin / name
            path.write_text("#!" + sys.executable + "\n" + script)
            path.chmod(0o755)
        self.environment = os.environ.copy()
        self.environment.update(
            HOME=str(self.home),
            CODEX_HOME=str(self.codex_home),
            CLAUDE_CONFIG_DIR=str(self.root / "claude"),
            AI_AGENT_SOURCE_ROOT=str(self.sources),
            PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
            PYTHON_COMMAND=sys.executable,
            PYTHONDONTWRITEBYTECODE="1",
            PLUGIN_TEST_CONTROL=str(self.control_path),
            PLUGIN_TEST_STATE=str(self.state_path),
            PLUGIN_TEST_EVENTS=str(self.events_path),
            PLUGIN_TEST_FIXTURES=str(self.fixtures),
        )
        for line in (REPOSITORY_ROOT / "manifests" / "sources.tsv").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            name, _, commit, destination = line.split("\t")
            checkout = self.fixtures / destination
            (checkout / ".git").mkdir(parents=True)
            (checkout / ".git" / "HEAD").write_text(commit + "\n")
            if name == "agent-skills":
                names = (REPOSITORY_ROOT / "manifests" / "agent-skills.txt").read_text().splitlines()
                for skill in names:
                    if skill:
                        self.write_skill(checkout / "skills" / skill, skill)
            elif name == "i-have-adhd":
                self.write_skill(checkout / "skills" / name, name)
                for directory, manifest in [
                    (".claude-plugin", {"name": name, "plugins": [{"name": name, "source": "./"}]}),
                    (".codex-plugin", {"name": name, "version": "0.1.0", "skills": "./skills/"}),
                ]:
                    (checkout / directory).mkdir()
                    filename = "marketplace.json" if directory == ".claude-plugin" else "plugin.json"
                    (checkout / directory / filename).write_text(json.dumps(manifest))

    @staticmethod
    def write_skill(directory, name):
        directory.mkdir(parents=True)
        (directory / "SKILL.md").write_text("---\nname: " + name + "\ndescription: Fixture.\n---\n")

    def run_bootstrap(self, *arguments, nvidia=False):
        self.control_path.write_text(json.dumps(self.control))
        command = ["bash", str(REPOSITORY_ROOT / "install-codex.sh")]
        if not nvidia:
            command.append("--without-nvidia")
        return subprocess.run(
            command + list(arguments),
            cwd=self.root,
            env=self.environment,
            text=True,
            capture_output=True,
            timeout=30,
        )

    def events(self):
        if not self.events_path.exists():
            return []
        return [json.loads(line) for line in self.events_path.read_text().splitlines()]

    def plugin_adds(self):
        return [event["args"][2] for event in self.events()
                if event["command"] == "codex" and event["args"][:2] == ["plugin", "add"]]

    def assert_no_install_changes(self):
        self.assertFalse(self.sources.exists(), "preflight downloaded a source")
        self.assertFalse(self.codex_home.exists(), "preflight changed the Codex environment")
        self.assertFalse(self.home.exists(), "preflight changed HOME")
        self.assertFalse(any(event["mutation"] for event in self.events()), self.events())

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_hugging_face_stops_before_nvidia_or_source_changes(self):
        self.control["available"] = [GITHUB]
        result = self.run_bootstrap("--apply", nvidia=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(HUGGING_FACE, result.stdout + result.stderr)
        self.assertIn("--skip-hugging-face", result.stdout + result.stderr)
        self.assert_no_install_changes()

    def test_missing_github_stops_before_source_changes(self):
        self.control["available"] = [HUGGING_FACE]
        result = self.run_bootstrap("--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(GITHUB, result.stdout + result.stderr)
        self.assert_no_install_changes()

    def test_skip_hugging_face_installs_local_adhd_from_fresh_source(self):
        self.control["available"] = [GITHUB]
        result = self.run_bootstrap("--skip-hugging-face", "--apply")
        self.assert_success(result)
        self.assertEqual(self.plugin_adds(), [GITHUB, ADHD])
        self.assertTrue((self.codex_home / "skills" / "backend-api-contracts" / "SKILL.md").is_file())
        state = json.loads(self.state_path.read_text())
        self.assertEqual(state["marketplaces"], ["i-have-adhd"])
        self.assertEqual(state["installed"], [GITHUB, ADHD])

    def test_compact_json_installed_plugins_are_not_reinstalled(self):
        self.state_path.write_text(json.dumps({"installed": [GITHUB, HUGGING_FACE, ADHD],
                                             "marketplaces": ["i-have-adhd"]}))
        self.control["available"] = []
        result = self.run_bootstrap("--apply")
        self.assert_success(result)
        self.assertEqual(self.plugin_adds(), [])
        self.assertFalse(any(event["args"][:3] == ["plugin", "marketplace", "add"]
                             for event in self.events()))

    def test_available_plugins_are_installed_instead_of_mistaken_for_installed(self):
        result = self.run_bootstrap("--apply")
        self.assert_success(result)
        self.assertEqual(self.plugin_adds(), [GITHUB, HUGGING_FACE, ADHD])

    def test_plugin_from_other_marketplace_does_not_satisfy_exact_id(self):
        self.state_path.write_text(json.dumps({"installed": ["github@different-marketplace"],
                                             "marketplaces": []}))
        result = self.run_bootstrap("--apply")
        self.assert_success(result)
        self.assertEqual(self.plugin_adds(), [GITHUB, HUGGING_FACE, ADHD])

    def test_explicit_installed_github_override_skips_add_and_continues_to_adhd(self):
        plugin_id = "github@openai-curated-remote"
        self.state_path.write_text(json.dumps({"installed": [plugin_id], "marketplaces": []}))
        self.control["available"] = []
        result = self.run_bootstrap("--github-plugin", plugin_id, "--skip-hugging-face", "--apply")
        self.assert_success(result)
        self.assertEqual(self.plugin_adds(), [ADHD])
        self.assertEqual(json.loads(self.state_path.read_text())["installed"], [plugin_id, ADHD])
        self.assertTrue((self.sources / "i-have-adhd" / "skills" / "i-have-adhd" / "SKILL.md").is_file())

    def test_explicit_available_github_override_installs_selected_id(self):
        plugin_id = "github@openai-curated-remote"
        self.control["available"] = [plugin_id]
        self.control["marketplaces"] = ["openai-curated-remote"]
        result = self.run_bootstrap("--github-plugin", plugin_id, "--skip-hugging-face", "--apply")
        self.assert_success(result)
        self.assertEqual(self.plugin_adds(), [plugin_id, ADHD])

    def test_missing_or_invalid_github_override_stops_before_changes(self):
        invalid_arguments = [
            ["--github-plugin"],
            ["--github-plugin", ""],
            ["--github-plugin", "github"],
            ["--github-plugin", "@openai-curated"],
            ["--github-plugin", "github@"],
            ["--github-plugin", "github@@openai-curated"],
        ]
        for arguments in invalid_arguments:
            with self.subTest(arguments=arguments):
                result = self.run_bootstrap("--apply", *arguments)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("github", result.stdout + result.stderr)
                self.assert_no_install_changes()

    def test_false_installed_flag_does_not_skip_installation(self):
        self.control["list_output"] = json.dumps({
            "installed": [{"pluginId": GITHUB, "installed": False}],
            "available": [{"pluginId": plugin_id, "installed": False}
                          for plugin_id in [GITHUB, HUGGING_FACE]],
        })
        result = self.run_bootstrap("--apply")
        self.assert_success(result)
        self.assertEqual(self.plugin_adds(), [GITHUB, HUGGING_FACE, ADHD])

    def test_invalid_json_or_failed_queries_stop_before_changes(self):
        controls = [
            {"list_output": "{invalid"},
            {"list_output": "{}"},
            {"list_output": "[]"},
            {"list_failure": True},
            {"marketplace_output": "not json"},
            {"marketplace_output": "{}"},
            {"marketplace_failure": True},
        ]
        for override in controls:
            with self.subTest(override=override):
                self.control = {"available": [GITHUB, HUGGING_FACE], **override}
                result = self.run_bootstrap("--apply")
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assert_no_install_changes()

    def test_missing_marketplace_is_reported_before_changes(self):
        self.control["marketplaces"] = []
        result = self.run_bootstrap("--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("openai-curated", result.stdout + result.stderr)
        self.assert_no_install_changes()

    def test_existing_local_marketplace_with_different_root_stops_before_changes(self):
        self.state_path.write_text(json.dumps({"installed": [], "marketplaces": ["i-have-adhd"]}))
        self.control["marketplace_roots"] = {"i-have-adhd": str(self.root / "other-source")}
        result = self.run_bootstrap("--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("i-have-adhd", result.stdout + result.stderr)
        self.assert_no_install_changes()

    def test_bad_existing_local_adhd_manifest_stops_before_skill_install(self):
        self.sources.mkdir()
        shutil.copytree(self.fixtures / "i-have-adhd", self.sources / "i-have-adhd")
        manifest = self.sources / "i-have-adhd" / ".claude-plugin" / "marketplace.json"
        manifest.write_text(json.dumps({"name": "different-marketplace", "plugins": []}))
        result = self.run_bootstrap("--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.codex_home / "skills").exists())
        self.assertEqual(self.plugin_adds(), [])

    def test_bad_downloaded_local_adhd_manifest_stops_before_skill_install(self):
        manifest = self.fixtures / "i-have-adhd" / ".claude-plugin" / "marketplace.json"
        manifest.write_text(json.dumps({"name": "different-marketplace", "plugins": []}))
        result = self.run_bootstrap("--apply")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.codex_home / "skills").exists())
        self.assertEqual(self.plugin_adds(), [])

    def test_retry_after_install_failure_preserves_successful_plugins_and_skills(self):
        self.control["fail_plugin"] = HUGGING_FACE
        first = self.run_bootstrap("--apply")
        self.assertNotEqual(first.returncode, 0)
        self.assertEqual(self.plugin_adds(), [GITHUB, HUGGING_FACE])
        skill = self.codex_home / "skills" / "backend-api-contracts" / "SKILL.md"
        original_stat = skill.stat()
        self.control.pop("fail_plugin")
        second = self.run_bootstrap("--skip-hugging-face", "--apply")
        self.assert_success(second)
        self.assertEqual(self.plugin_adds(), [GITHUB, HUGGING_FACE, ADHD])
        self.assertEqual(skill.stat().st_ino, original_stat.st_ino)
        self.assertEqual(skill.stat().st_mtime_ns, original_stat.st_mtime_ns)

    def test_default_dry_run_uses_read_queries_without_install_changes(self):
        result = self.run_bootstrap("--skip-hugging-face")
        self.assert_success(result)
        self.assertIn("[dry-run]", result.stdout)
        self.assertTrue(any(event["args"][:2] == ["plugin", "list"] for event in self.events()))
        self.assert_no_install_changes()

    def test_preflight_uses_utf8_input_and_lf_output_with_windows_text_wrappers(self):
        helper = REPOSITORY_ROOT / "scripts" / "codex_plugins.py"
        wrapper = "\n".join([
            "import io, runpy, sys",
            "script = sys.argv[1]",
            "sys.argv = [script] + sys.argv[2:]",
            "sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='cp950')",
            "sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='cp950', newline='\\r\\n')",
            "runpy.run_path(script, run_name='__main__')",
        ])
        snapshot = {"installed": [{"pluginId": GITHUB, "installed": True}], "available": []}
        marketplaces = {"marketplaces": [{"name": "openai-curated", "root": "C:/使用者/技能"}]}
        payload = (json.dumps(snapshot, ensure_ascii=False) + "\x1e"
                   + json.dumps(marketplaces, ensure_ascii=False)).encode("utf-8")
        result = subprocess.run(
            [sys.executable, "-c", wrapper, str(helper), "preflight", "--adhd-source",
             str(self.sources / "i-have-adhd"), "--skip-adhd", "--skip-hugging-face"],
            cwd=self.root,
            env=self.environment,
            input=payload,
            capture_output=True,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"plugin\tgithub@openai-curated\n", result.stdout)
        self.assertNotIn(b"\r", result.stdout)
        self.assertFalse(self.events_path.exists(), "helper invoked a CLI")


if __name__ == "__main__":
    unittest.main()
