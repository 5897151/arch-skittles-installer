from pathlib import Path
import hashlib
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
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
        self.assertIn("release-signoff.json", text)
        self.assertIn("scripts/check_release_signoff.py", text)
        self.assertIn("scripts/extract_generated_shell.py CHROOT_SCRIPT", text)
        self.assertIn("scripts/extract_generated_shell.py DOCTOR_SCRIPT", text)
        self.assertIn("shellcheck /tmp/skittles-chroot.sh /tmp/skittles-doctor.sh", text)
        self.assertIn("archlinux:latest", text)
        self.assertIn("bash tests/test_arch_pacman_preflight.sh", text)
        arch_script = (ROOT / "tests/test_arch_pacman_preflight.sh").read_text(encoding="utf-8")
        self.assertIn("pacman -Syu --noconfirm --needed", arch_script)
        self.assertIn("-Sy --noconfirm", arch_script)
        self.assertIn("-Sp --noconfirm", arch_script)
        self.assertIn("-Si -- \"$package\"", arch_script)
        self.assertIn("stat -c '%a' \"$WORKDIR\"", arch_script)
        self.assertIn("copied_user", arch_script)
        self.assertIn("source_sandbox_policy", arch_script)
        self.assertIn("copied_sandbox_policy", arch_script)
        self.assertIn('[[ $copied_sandbox_policy == "$source_sandbox_policy" ]]', arch_script)
        self.assertIn("PACKAGE-PERMISSION LOGIC: NOT PROVEN", arch_script)
        self.assertIn("PACMAN SANDBOX IN HOSTED CONTAINER: BLOCKED", arch_script)
        self.assertNotIn("DisableSandbox", text)
        installer = (ROOT / "skittles-installer.sh").read_text(encoding="utf-8")
        self.assertNotIn("DisableSandbox", installer)

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

    def test_release_prerequisites_execute_fail_closed(self):
        data = yaml.safe_load(RELEASE.read_text(encoding="utf-8"))
        step = next(
            item for item in data["jobs"]["release"]["steps"]
            if item.get("name") == "Require release prerequisites and matching version"
        )
        license_path = ROOT / "LICENSE"
        self.assertTrue(license_path.exists(), "Apache-2.0 LICENSE must be committed")
        self.assertIn("Version 2.0, January 2004", license_path.read_text(encoding="utf-8"))
        env = os.environ.copy()
        env["GITHUB_REF_NAME"] = "v1.0.0-rc.1"
        with tempfile.TemporaryDirectory() as td:
            fixture = Path(td)
            shutil.copy2(ROOT / "skittles-installer.sh", fixture / "skittles-installer.sh")
            missing = subprocess.run(["bash", "-c", step["run"]], cwd=fixture, env=env, text=True, capture_output=True)
            self.assertNotEqual(missing.returncode, 0)
            self.assertIn("LICENSE is required", missing.stderr)
            shutil.copy2(license_path, fixture / "LICENSE")
            matching = subprocess.run(["bash", "-c", step["run"]], cwd=fixture, env=env, text=True, capture_output=True)
            self.assertEqual(matching.returncode, 0, matching.stderr)
            env["GITHUB_REF_NAME"] = "v1.0.0-rc.9"
            mismatch = subprocess.run(["bash", "-c", step["run"]], cwd=fixture, env=env, text=True, capture_output=True)
            self.assertNotEqual(mismatch.returncode, 0)
            self.assertIn("does not match installer VERSION", mismatch.stderr)

    def test_release_bundle_contains_required_public_files(self):
        text = RELEASE.read_text(encoding="utf-8")
        for item in ["skittles-installer.sh", "README.md", "LICENSE", "CHANGELOG.md", "SECURITY.md", "docs", "release-signoff.json"]:
            with self.subTest(item=item):
                self.assertIn(item, text)
        self.assertIn('chmod 0755 "dist/${bundle}/skittles-installer.sh"', text)
        self.assertNotIn('cp -R docs tests', text)

    def test_release_asset_recipe_is_byte_reproducible_and_clean(self):
        data = yaml.safe_load(RELEASE.read_text(encoding="utf-8"))
        step = next(
            item for item in data["jobs"]["release"]["steps"]
            if item.get("name") == "Build reproducible release assets"
        )
        license_path = ROOT / "LICENSE"
        dist = ROOT / "dist"
        self.assertTrue(license_path.exists(), "Apache-2.0 LICENSE must be committed")
        env = os.environ.copy()
        env.update(
            GITHUB_REF_NAME="v1.0.0-rc.1",
            GITHUB_SHA="0123456789abcdef0123456789abcdef01234567",
        )
        hashes = []
        try:
            for _ in range(2):
                proc = subprocess.run(
                    ["bash", "-c", step["run"]], cwd=ROOT, env=env,
                    text=True, capture_output=True,
                )
                self.assertEqual(proc.returncode, 0, proc.stderr)
                archive = dist / "skittles-1.0.0-rc.1.tar.gz"
                hashes.append(hashlib.sha256(archive.read_bytes()).hexdigest())
                with tarfile.open(archive, "r:gz") as tf:
                    names = tf.getnames()
                    root = "skittles-1.0.0-rc.1"
                    required = {
                        f"{root}/skittles-installer.sh",
                        f"{root}/README.md",
                        f"{root}/LICENSE",
                        f"{root}/CHANGELOG.md",
                        f"{root}/SECURITY.md",
                        f"{root}/CONTRIBUTING.md",
                        f"{root}/release-signoff.json",
                        f"{root}/SOURCE_COMMIT",
                    }
                    self.assertTrue(required <= set(names))
                    self.assertFalse(any(name.startswith(f"{root}/tests/") for name in names))
                    self.assertFalse(any(name.startswith(f"{root}/.github/") for name in names))
                    mode = tf.getmember(f"{root}/skittles-installer.sh").mode & 0o777
                    self.assertEqual(mode, 0o755)
                    source = tf.extractfile(f"{root}/SOURCE_COMMIT").read().decode().strip()
                    self.assertEqual(source, env["GITHUB_SHA"])
                verify = subprocess.run(
                    ["sha256sum", "-c", "SHA256SUMS"], cwd=dist,
                    text=True, capture_output=True,
                )
                self.assertEqual(verify.returncode, 0, verify.stderr)
            self.assertEqual(hashes[0], hashes[1])
        finally:
            shutil.rmtree(dist, ignore_errors=True)

    def test_repository_hygiene_scanner_passes_current_tree(self):
        proc = subprocess.run(
            ["python3", "scripts/audit_repository.py"], cwd=ROOT,
            text=True, capture_output=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("Repository hygiene: PASS", proc.stdout)

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
