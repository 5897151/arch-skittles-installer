from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
META = (ROOT / "docs/GITHUB-METADATA.md").read_text(encoding="utf-8")
RC_NOTES = (ROOT / "docs/RELEASE-NOTES-v1.0.0-rc.1.md").read_text(encoding="utf-8")
STABLE_NOTES = (ROOT / "docs/RELEASE-NOTES-v1.0.0.md").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")


class ReleaseMetadataTests(unittest.TestCase):
    def test_repository_metadata_has_three_descriptions_and_blank_website(self):
        self.assertIn("### Recommended", META)
        self.assertIn("### Short", META)
        self.assertIn("### Technical", META)
        self.assertRegex(META, r"## Website\n\n\n## Topics")
        recommended = re.search(r"### Recommended\n\n(.+)", META).group(1)
        self.assertLess(len(recommended), 250)

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
        self.assertIn("No owner-authorized software license", RC_NOTES)

    def test_stable_notes_are_explicitly_draft_gated(self):
        self.assertIn("# SKITTLES v1.0.0", STABLE_NOTES)
        self.assertIn("DRAFT:", STABLE_NOTES)
        self.assertIn("grep -q 'DRAFT:'", WORKFLOW)

    def test_release_workflow_uses_tag_specific_notes_and_hardware_gates(self):
        self.assertIn('notes_file="docs/RELEASE-NOTES-${GITHUB_REF_NAME}.md"', WORKFLOW)
        self.assertIn("hardware sign-off table still contains NOT TESTED", WORKFLOW)
        self.assertIn("performance measurements are not recorded", WORKFLOW)
        self.assertIn('--notes-file "$notes_file"', WORKFLOW)

    def test_expected_assets_match_workflow(self):
        for name in ['"dist/${bundle}.tar.gz"', '"dist/skittles-installer-${version}.sh"', "SHA256SUMS"]:
            self.assertIn(name, WORKFLOW)


if __name__ == "__main__":
    unittest.main()
