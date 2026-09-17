from pathlib import Path
import re
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]
CI = ROOT / ".github/workflows/ci.yml"
RELEASE = ROOT / ".github/workflows/release.yml"


class GitHubInfrastructureTests(unittest.TestCase):
    def test_workflow_yaml_parses(self):
        for path in (CI, RELEASE, ROOT / ".github/ISSUE_TEMPLATE/bug_report.yml", ROOT / ".github/dependabot.yml"):
            with self.subTest(path=path):
                data = yaml.safe_load(path.read_text(encoding="utf-8"))
                self.assertIsNotNone(data)

    def test_ci_is_non_destructive_and_minimally_permissioned(self):
        text = CI.read_text(encoding="utf-8")
        self.assertIn("permissions:\n  contents: read", text)
        self.assertNotIn("contents: write", text)
        self.assertNotIn("sudo ", text)
        self.assertNotIn("/dev/", text)
        self.assertNotRegex(text, r"bash skittles-installer\.sh(?:\s|$)")
        self.assertIn("bash -n skittles-installer.sh", text)
        self.assertIn("shellcheck skittles-installer.sh", text)
        self.assertIn("python3 -m unittest discover -s tests -v", text)

    def test_external_actions_are_first_party_and_sha_pinned(self):
        for path in (CI, RELEASE):
            text = path.read_text(encoding="utf-8")
            uses = re.findall(r"uses:\s*([^\s#]+)", text)
            self.assertTrue(uses)
            for action in uses:
                with self.subTest(path=path.name, action=action):
                    self.assertTrue(action.startswith("actions/"))
                    self.assertRegex(action, r"^actions/[A-Za-z0-9_.-]+@[0-9a-f]{40}$")

    def test_release_is_tag_only_and_scopes_write_permissions_to_release_job(self):
        text = RELEASE.read_text(encoding="utf-8")
        self.assertIn('tags:\n      - "v*"', text)
        self.assertIn("permissions:\n  contents: read", text)
        self.assertIn("contents: write", text)
        self.assertIn("id-token: write", text)
        self.assertIn("attestations: write", text)
        self.assertIn("artifact-metadata: write", text)
        self.assertNotIn("pull_request:", text)

    def test_release_requires_license_and_version_tag_match(self):
        text = RELEASE.read_text(encoding="utf-8")
        self.assertIn("test -s LICENSE", text)
        self.assertIn('test "${GITHUB_REF_NAME}" = "v${version}"', text)
        self.assertIn("sha256sum -c SHA256SUMS", text)
        self.assertIn("actions/attest@", text)
        self.assertIn("gh release create", text)

    def test_release_bundle_contains_required_public_files(self):
        text = RELEASE.read_text(encoding="utf-8")
        for item in ["skittles-installer.sh", "README.md", "LICENSE", "CHANGELOG.md", "SECURITY.md", "docs", "tests"]:
            with self.subTest(item=item):
                self.assertIn(item, text)

    def test_bug_template_contains_release_and_redaction_fields(self):
        text = (ROOT / ".github/ISSUE_TEMPLATE/bug_report.yml").read_text(encoding="utf-8")
        for token in [
            "SKITTLES version", "Arch ISO date", "Profile", "Running kernel", "GPU",
            "skittles-doctor", "Before any destructive operation", "drive serial numbers",
            "/etc/NetworkManager/system-connections/", "SECURITY.md",
        ]:
            with self.subTest(token=token):
                self.assertIn(token, text)


if __name__ == "__main__":
    unittest.main()
