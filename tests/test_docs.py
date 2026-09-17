from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skittles-installer.sh"
README = ROOT / "README.md"
REQUIRED_DOCS = [
    ROOT / "README.md",
    ROOT / "CHANGELOG.md",
    ROOT / "SECURITY.md",
    ROOT / "CONTRIBUTING.md",
    ROOT / "docs/ARCHITECTURE.md",
    ROOT / "docs/PRIVACY.md",
    ROOT / "docs/SECURITY-MODEL.md",
    ROOT / "docs/PERFORMANCE.md",
    ROOT / "docs/RECOVERY.md",
    ROOT / "docs/TESTING.md",
    ROOT / "docs/RELEASE.md",
]


class DocumentationConsistencyTests(unittest.TestCase):
    def test_required_documents_exist_and_are_nontrivial(self):
        for path in REQUIRED_DOCS:
            with self.subTest(path=path.name):
                self.assertTrue(path.is_file())
                self.assertGreater(len(path.read_text(encoding="utf-8").splitlines()), 20)

    def test_readme_release_candidate_version_matches_installer(self):
        proc = subprocess.run(
            ["bash", str(SCRIPT), "--version"], cwd=ROOT, text=True, capture_output=True, check=True
        )
        version = proc.stdout.strip()
        text = README.read_text(encoding="utf-8")
        self.assertIn(f"`{version}`", text)
        self.assertIn("release candidate, not stable", text)

    def test_readme_mentions_every_long_cli_option(self):
        help_text = subprocess.run(
            ["bash", str(SCRIPT), "--help"], cwd=ROOT, text=True, capture_output=True, check=True
        ).stdout
        self.assertIn("--profile=minimal|gaming", help_text)
        self.assertIn("--wipe=zero|signatures", help_text)
        options = {
            "--profile=minimal", "--profile=gaming", "--packages", "--check",
            "--wipe=zero", "--wipe=signatures", "--allow-discards", "--demo",
            "--version", "--help",
        }
        text = README.read_text(encoding="utf-8")
        for option in options:
            with self.subTest(option=option):
                self.assertIn(option, text)

    def test_local_markdown_links_resolve(self):
        for source in REQUIRED_DOCS:
            text = source.read_text(encoding="utf-8")
            for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
                if "://" in target or target.startswith("#"):
                    continue
                local = target.split("#", 1)[0]
                if not local:
                    continue
                with self.subTest(source=source.name, target=target):
                    self.assertTrue((source.parent / local).resolve().exists())

    def test_readme_profile_claims_match_package_output(self):
        minimal = set(subprocess.run(
            ["bash", str(SCRIPT), "--profile=minimal", "--packages"], cwd=ROOT,
            text=True, capture_output=True, check=True
        ).stdout.splitlines())
        gaming = set(subprocess.run(
            ["bash", str(SCRIPT), "--profile=gaming", "--packages"], cwd=ROOT,
            text=True, capture_output=True, check=True
        ).stdout.splitlines())
        self.assertNotIn("steam", minimal)
        self.assertTrue({"steam", "gamemode", "mangohud", "ntsync-autoload"} <= gaming)
        text = README.read_text(encoding="utf-8")
        self.assertIn("`linux` + `linux-lts`", text)
        self.assertIn("NTSync autoload", text)

    def test_license_state_matches_readme(self):
        license_path = ROOT / "LICENSE"
        text = README.read_text(encoding="utf-8")
        if license_path.exists():
            self.assertGreater(license_path.stat().st_size, 0)
            self.assertNotIn("No software license has been selected", text)
        else:
            self.assertIn("No software license has been selected", text)
            self.assertIn("blocker for `v1.0.0`", text)


if __name__ == "__main__":
    unittest.main()
