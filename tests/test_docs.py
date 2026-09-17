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
    ROOT / "docs/RELEASE-AUDIT.md",
    ROOT / "docs/RELEASE-DECISION.md",
    ROOT / "docs/RELEASE-NOTES-v1.0.0-rc.1.md",
    ROOT / "docs/RELEASE-NOTES-v1.0.0.md",
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
        markdown = [p for p in ROOT.rglob("*.md") if ".git" not in p.parts]
        for source in markdown:
            text = source.read_text(encoding="utf-8")
            for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
                if "://" in target or target.startswith("#") or target.startswith("mailto:"):
                    continue
                local = target.split("#", 1)[0]
                if not local:
                    continue
                with self.subTest(source=source.relative_to(ROOT).as_posix(), target=target):
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
        license_text = license_path.read_text(encoding="utf-8")
        self.assertIn("Apache License", license_text)
        self.assertIn("Version 2.0, January 2004", license_text)
        self.assertIn("Apache License 2.0", text)
        self.assertNotIn("No software license has been selected", text)

    def test_recovery_uses_arch_chroot_resolver_handoff(self):
        recovery = (ROOT / "docs/RECOVERY.md").read_text(encoding="utf-8")
        self.assertIn("arch-chroot /mnt", recovery)
        self.assertNotIn("mkdir -p /mnt/run/systemd/resolve", recovery)
        self.assertNotIn("cp -L /etc/resolv.conf /mnt/run/systemd/resolve/stub-resolv.conf", recovery)
        self.assertIn("fix networking/resolution in the live ISO first", recovery)
        self.assertNotIn("findmnt /mnt /mnt/boot", recovery)
        self.assertIn("findmnt -T /mnt", recovery)
        self.assertIn("findmnt -T /mnt/boot", recovery)
        self.assertNotIn("sudo cryptsetup luksHeaderBackup", recovery)


if __name__ == "__main__":
    unittest.main()
