from pathlib import Path
import hashlib
import json
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
META = (ROOT / "docs/GITHUB-METADATA.md").read_text(encoding="utf-8")
RC_NOTES = (ROOT / "docs/RELEASE-NOTES-v1.0.0-rc.1.md").read_text(encoding="utf-8")
STABLE_NOTES = (ROOT / "docs/RELEASE-NOTES-v1.0.0.md").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
SIGNOFF = ROOT / "release-signoff.json"
SIGNOFF_CHECK = ROOT / "scripts/check_release_signoff.py"


class ReleaseMetadataTests(unittest.TestCase):
    def test_repository_metadata_has_final_description_and_blank_website(self):
        self.assertIn("## Description", META)
        self.assertRegex(META, r"## Website\n\n\n## Topics")
        description = re.search(r"## Description\n\n(.+)", META).group(1)
        self.assertLessEqual(len(description), 160)
        self.assertIn("i7-8700K", description)
        self.assertIn("RTX 3060 Ti", description)

    def test_topics_are_focused(self):
        block = re.search(r"## Topics\n\n```text\n(.*?)\n```", META, re.S).group(1)
        topics = block.splitlines()
        self.assertGreaterEqual(len(topics), 10)
        self.assertLessEqual(len(topics), 15)
        self.assertEqual(len(topics), len(set(topics)))
        self.assertIn("arch-linux", topics)
        self.assertIn("nvidia", topics)
        self.assertIn("luks2", topics)

    def test_release_notes_have_required_sections(self):
        required = [
            "## Highlights", "## Hardware target", "## Safety", "## Security & privacy",
            "## Gaming", "## Recovery", "## Known limitations", "## Verification",
            "## Upgrade note",
        ]
        for notes in (RC_NOTES, STABLE_NOTES):
            for heading in required:
                with self.subTest(heading=heading):
                    self.assertIn(heading, notes)
            self.assertIn("Do not run SKITTLES to upgrade", notes)
            self.assertIn("sha256sum -c SHA256SUMS", notes)
            self.assertIn("gh attestation verify", notes)

    def test_rc_notes_match_current_version_and_are_honest(self):
        self.assertTrue(RC_NOTES.startswith("# SKITTLES v1.0.0-rc.1"))
        self.assertIn("release candidate", RC_NOTES)
        self.assertIn("NOT TESTED", RC_NOTES)
        self.assertIn("Apache License 2.0", RC_NOTES)

    def test_stable_notes_are_explicitly_draft_gated(self):
        self.assertIn("# SKITTLES v1.0.0", STABLE_NOTES)
        self.assertIn("DRAFT:", STABLE_NOTES)
        self.assertIn("DRAFT:", SIGNOFF_CHECK.read_text(encoding="utf-8"))

    def test_release_workflow_uses_tag_specific_notes_and_fail_closed_stable_gate(self):
        self.assertIn('notes_file="docs/RELEASE-NOTES-${GITHUB_REF_NAME}.md"', WORKFLOW)
        self.assertIn("python3 scripts/check_release_signoff.py", WORKFLOW)
        self.assertIn("release-signoff.json docs/PERFORMANCE.md", WORKFLOW)
        self.assertIn('--notes-file "$notes_file"', WORKFLOW)
        self.assertNotIn("hardware sign-off table still contains NOT TESTED", WORKFLOW)

    def _valid_signoff_fixture(self, directory: Path):
        data = json.loads(SIGNOFF.read_text(encoding="utf-8"))
        for key in data["required"]:
            data["required"][key] = "PASS"
        performance = directory / "docs/PERFORMANCE.md"
        performance.parent.mkdir(parents=True)
        performance.write_text("# Performance evidence\n\nMeasured on release hardware.\n", encoding="utf-8")
        data["evidence"]["performance_file"] = "docs/PERFORMANCE.md"
        data["evidence"]["performance_sha256"] = hashlib.sha256(performance.read_bytes()).hexdigest()
        signoff = directory / "release-signoff.json"
        signoff.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        notes = directory / "stable.md"
        notes.write_text("# Stable notes\n\nValidated release.\n", encoding="utf-8")
        return signoff, performance, notes, data

    def _run_signoff(self, signoff: Path, performance: Path, notes: Path):
        return subprocess.run(
            ["python3", str(SIGNOFF_CHECK), str(signoff), str(performance), str(notes)],
            cwd=signoff.parent,
            text=True,
            capture_output=True,
        )

    def test_repository_signoff_defaults_fail_closed(self):
        data = json.loads(SIGNOFF.read_text(encoding="utf-8"))
        self.assertEqual(data["schema"], 1)
        self.assertEqual(data["release"], "1.0.0")
        self.assertTrue(data["required"])
        self.assertEqual(set(data["required"].values()), {"NOT TESTED"})
        self.assertIsNone(data["evidence"]["performance_sha256"])

    def test_stable_gate_accepts_valid_all_pass_fixture(self):
        with tempfile.TemporaryDirectory() as td:
            signoff, performance, notes, _ = self._valid_signoff_fixture(Path(td))
            proc = self._run_signoff(signoff, performance, notes)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertIn("Stable release sign-off: PASS", proc.stdout)

    def test_stable_gate_rejects_fail_status(self):
        with tempfile.TemporaryDirectory() as td:
            signoff, performance, notes, data = self._valid_signoff_fixture(Path(td))
            data["required"]["linux_boot"] = "FAIL"
            signoff.write_text(json.dumps(data), encoding="utf-8")
            self.assertNotEqual(self._run_signoff(signoff, performance, notes).returncode, 0)

    def test_stable_gate_rejects_not_tested_status(self):
        with tempfile.TemporaryDirectory() as td:
            signoff, performance, notes, data = self._valid_signoff_fixture(Path(td))
            data["required"]["suspend_resume_linux"] = "NOT TESTED"
            signoff.write_text(json.dumps(data), encoding="utf-8")
            self.assertNotEqual(self._run_signoff(signoff, performance, notes).returncode, 0)

    def test_stable_gate_rejects_blocked_warn_and_empty_statuses(self):
        for status in ("BLOCKED", "WARN", ""):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as td:
                signoff, performance, notes, data = self._valid_signoff_fixture(Path(td))
                data["required"]["recovery_repair_grub"] = status
                signoff.write_text(json.dumps(data), encoding="utf-8")
                self.assertNotEqual(self._run_signoff(signoff, performance, notes).returncode, 0)

    def test_stable_gate_rejects_missing_required_key(self):
        with tempfile.TemporaryDirectory() as td:
            signoff, performance, notes, data = self._valid_signoff_fixture(Path(td))
            del data["required"]["nvidia_linux_lts"]
            signoff.write_text(json.dumps(data), encoding="utf-8")
            self.assertNotEqual(self._run_signoff(signoff, performance, notes).returncode, 0)

    def test_stable_gate_rejects_missing_or_malformed_signoff(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            _, performance, notes, _ = self._valid_signoff_fixture(root)
            missing = root / "missing.json"
            self.assertNotEqual(self._run_signoff(missing, performance, notes).returncode, 0)
            malformed = root / "bad.json"
            malformed.write_text("{ definitely not json", encoding="utf-8")
            self.assertNotEqual(self._run_signoff(malformed, performance, notes).returncode, 0)

    def test_stable_gate_rejects_missing_or_changed_performance_evidence(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            signoff, performance, notes, _ = self._valid_signoff_fixture(root)
            performance.unlink()
            self.assertNotEqual(self._run_signoff(signoff, performance, notes).returncode, 0)
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            signoff, performance, notes, _ = self._valid_signoff_fixture(root)
            performance.write_text("changed after sign-off\n", encoding="utf-8")
            self.assertNotEqual(self._run_signoff(signoff, performance, notes).returncode, 0)

    def test_stable_gate_rejects_draft_release_notes(self):
        with tempfile.TemporaryDirectory() as td:
            signoff, performance, notes, _ = self._valid_signoff_fixture(Path(td))
            notes.write_text("DRAFT: not approved\n", encoding="utf-8")
            self.assertNotEqual(self._run_signoff(signoff, performance, notes).returncode, 0)

    def test_expected_assets_match_workflow(self):
        for name in ['"dist/${bundle}.tar.gz"', '"dist/skittles-installer-${version}.sh"', "SHA256SUMS", "release-signoff.json"]:
            self.assertIn(name, WORKFLOW)


if __name__ == "__main__":
    unittest.main()
