import configparser
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skittles-installer.sh"
TEXT = SCRIPT.read_text(encoding="utf-8")


def run_bash(body: str, *, check=False):
    command = f"source {shlex.quote(str(SCRIPT))}\n{body}"
    return subprocess.run(
        ["bash", "-c", command],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=check,
    )


def heredoc(tag: str) -> str:
    match = re.search(
        rf"<<'{re.escape(tag)}'\n(.*?)\n{re.escape(tag)}(?:\n|$)",
        TEXT,
        flags=re.S,
    )
    if not match:
        raise AssertionError(f"missing heredoc {tag}")
    return match.group(1) + "\n"


class CliTests(unittest.TestCase):
    def test_version_matches_semver_constant(self):
        proc = subprocess.run(
            ["bash", str(SCRIPT), "--version"], cwd=ROOT, text=True, capture_output=True, check=True
        )
        version = proc.stdout.strip()
        declared = re.search(r"^readonly VERSION=(\S+)$", TEXT, re.M).group(1)
        self.assertEqual(version, declared)
        self.assertRegex(version, r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?$")

    def test_help_documents_every_supported_long_option(self):
        help_proc = subprocess.run(
            ["bash", str(SCRIPT), "--help"], cwd=ROOT, text=True, capture_output=True, check=True
        )
        help_text = help_proc.stdout
        expected = {
            "--check",
            "--wipe=zero",
            "--wipe=signatures",
            "--allow-discards",
            "--demo",
            "--profile=minimal",
            "--profile=gaming",
            "--packages",
            "--version",
            "--help",
        }
        for option in expected:
            self.assertIn(option, help_text)
        case_body = re.search(r"parse_args\(\).*?case \"\$arg\" in(.*?)esac", TEXT, re.S).group(1)
        for option in expected:
            self.assertIn(option, case_body)

    def test_unknown_option_fails(self):
        proc = subprocess.run(
            ["bash", str(SCRIPT), "--definitely-not-an-option"],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Unknown argument", proc.stderr)


class ProfileTests(unittest.TestCase):
    def packages(self, profile: str):
        proc = subprocess.run(
            ["bash", str(SCRIPT), f"--profile={profile}", "--packages"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=True,
        )
        return set(proc.stdout.splitlines())

    def test_minimal_profile_kernel_and_nvidia_strategy(self):
        packages = self.packages("minimal")
        required = {
            "linux", "linux-lts", "nvidia-open", "nvidia-open-lts", "nvidia-utils",
            "networkmanager", "grub", "cryptsetup", "nftables", "zram-generator",
        }
        self.assertTrue(required <= packages)
        self.assertNotIn("nvidia-open-dkms", packages)
        self.assertNotIn("linux-headers", packages)
        self.assertNotIn("linux-lts-headers", packages)
        self.assertNotIn("steam", packages)
        self.assertNotIn("gamemode", packages)

    def test_gaming_profile_adds_only_expected_explicit_gaming_stack(self):
        minimal = self.packages("minimal")
        gaming = self.packages("gaming")
        expected_extra = {
            "steam", "lib32-nvidia-utils", "lib32-vulkan-icd-loader",
            "gamemode", "lib32-gamemode", "mangohud", "lib32-mangohud", "ntsync-autoload",
        }
        self.assertEqual(gaming - minimal, expected_extra)


class PureShellFunctionTests(unittest.TestCase):
    def test_valid_username(self):
        valid = ["alice", "_service", "a1", "user-name", "user_name"]
        invalid = ["root", "Auser", "1user", "has space", "", "x" * 33]
        for username in valid:
            with self.subTest(username=username):
                self.assertEqual(run_bash(f"valid_username {shlex.quote(username)}").returncode, 0)
        for username in invalid:
            with self.subTest(username=username):
                self.assertNotEqual(run_bash(f"valid_username {shlex.quote(username)}").returncode, 0)

    def test_set_target_partition_suffixes(self):
        proc = run_bash("set_target /dev/sda; printf '%s %s' \"$EFI_PART\" \"$ROOT_PART\"")
        self.assertEqual(proc.stdout, "/dev/sda1 /dev/sda2")
        proc = run_bash("set_target /dev/nvme0n1; printf '%s %s' \"$EFI_PART\" \"$ROOT_PART\"")
        self.assertEqual(proc.stdout, "/dev/nvme0n1p1 /dev/nvme0n1p2")

    def test_disk_attribute_protection_reasons(self):
        cases = [
            ("part 0 0 sata ''", "not a whole installable disk"),
            ("disk 1 0 sata ''", "read-only or unreadable"),
            ("disk 0 1 sata ''", "removable media protected"),
            ("disk 0 0 usb ''", "USB / installation media protected"),
            ("disk 0 0 sata /mnt/data", "mounted filesystem or active swap"),
        ]
        for args, expected in cases:
            with self.subTest(args=args):
                proc = run_bash(f"disk_attribute_problem {args}")
                self.assertEqual(proc.stdout, expected)

    def test_menu_index_rejects_expressions_and_bounds(self):
        body = "DRIVES=(a b c); "
        good = run_bash(body + "menu_index 2")
        self.assertEqual(good.returncode, 0)
        self.assertEqual(good.stdout, "1")
        for value in ["0", "4", "1+1", "1[0]", "-1", "abc", "1000"]:
            with self.subTest(value=value):
                proc = run_bash(body + f"menu_index {shlex.quote(value)}")
                self.assertNotEqual(proc.returncode, 0)

    def test_plan_digest_is_stable_and_bound_to_plan(self):
        setup = """
PROFILE=minimal
WIPE_MODE=zero
ALLOW_DISCARDS=0
TARGET_INDEX=0
DRIVES=(/dev/sda /dev/sdb)
DRIVE_IDS=(id-a id-b)
DRIVE_BYTES=(100 200)
EXTRA_INDICES=(1)
"""
        proc = run_bash(setup + "a=$(plan_digest); b=$(plan_digest); printf '%s\\n%s\\n' \"$a\" \"$b\"")
        a, b = proc.stdout.splitlines()
        self.assertEqual(a, b)
        mutations = [
            "WIPE_MODE=signatures",
            "PROFILE=gaming",
            "ALLOW_DISCARDS=1",
            "DRIVE_IDS[1]=changed",
            "DRIVE_BYTES[0]=101",
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                proc = run_bash(setup + f"a=$(plan_digest); {mutation}; b=$(plan_digest); [[ $a != $b ]]")
                self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_authorization_refuses_unconfirmed_drive(self):
        body = """
TARGET_INDEX=0
DRIVES=(/dev/sda /dev/sdb)
DRIVE_IDS=(id-a id-b)
DRIVE_BYTES=(100 200)
EXTRA_INDICES=()
assert_authorized_drive /dev/sdb id-b 200
"""
        proc = run_bash(body)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("not in the confirmed plan", proc.stderr)


class DestructivePathMockTests(unittest.TestCase):
    def test_zero_wipe_writes_exact_bytes_only_to_temp_file(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "ordinary-file.bin"
            target.write_bytes(b"X" * 20000)
            body = f"""
require_approved_plan() {{ :; }}
assert_authorized_drive() {{ :; }}
assert_same_disk() {{ :; }}
partprobe() {{ :; }}
udevadm() {{ :; }}
log() {{ :; }}
WIPE_MODE=zero
clear_disk {shlex.quote(str(target))} fake-id 12345
"""
            proc = run_bash(body)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            data = target.read_bytes()
            self.assertEqual(len(data), 12345)
            self.assertEqual(set(data), {0})

    def test_signature_wipe_uses_only_mocked_disk_tools(self):
        with tempfile.TemporaryDirectory() as td:
            trace = Path(td) / "trace"
            body = f"""
TRACE={shlex.quote(str(trace))}
require_approved_plan() {{ :; }}
assert_authorized_drive() {{ :; }}
assert_same_disk() {{ :; }}
log() {{ :; }}
lsblk() {{ printf '%s\\n' /dev/TESTDISK /dev/TESTDISK1 /dev/TESTDISK2; }}
wipefs() {{ printf 'wipefs:%s\\n' \"$*\" >> \"$TRACE\"; }}
sgdisk() {{ printf 'sgdisk:%s\\n' \"$*\" >> \"$TRACE\"; }}
partprobe() {{ printf 'partprobe:%s\\n' \"$*\" >> \"$TRACE\"; }}
udevadm() {{ printf 'udevadm:%s\\n' \"$*\" >> \"$TRACE\"; }}
WIPE_MODE=signatures
clear_disk /dev/TESTDISK fake-id 999
"""
            proc = run_bash(body)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            lines = trace.read_text().splitlines()
            self.assertIn("wipefs:--all /dev/TESTDISK1", lines)
            self.assertIn("wipefs:--all /dev/TESTDISK2", lines)
            self.assertIn("wipefs:--all /dev/TESTDISK", lines)
            self.assertIn("sgdisk:--zap-all /dev/TESTDISK", lines)
            self.assertIn("partprobe:/dev/TESTDISK", lines)
            self.assertIn("udevadm:settle --timeout=30", lines)

    def test_extra_wipe_cannot_start_before_install_success(self):
        with tempfile.TemporaryDirectory() as td:
            marker = Path(td) / "clear-called"
            body = f"""
require_approved_plan() {{ :; }}
clear_disk() {{ touch {shlex.quote(str(marker))}; }}
ARCH_INSTALLED=0
TARGET_INDEX=0
DRIVES=(/dev/TESTA /dev/TESTB)
DRIVE_IDS=(a b)
DRIVE_BYTES=(100 200)
EXTRA_INDICES=(1)
wipe_extra_drives
"""
            proc = run_bash(body)
            self.assertNotEqual(proc.returncode, 0)
            self.assertFalse(marker.exists())
            self.assertIn("only be wiped after a successful installation", proc.stderr)


class GeneratedConfigurationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.chroot = heredoc("CHROOT_SCRIPT")
        cls.doctor = heredoc("DOCTOR_SCRIPT")

    def test_generated_shell_scripts_parse(self):
        for name, content in [("chroot", self.chroot), ("doctor", self.doctor)]:
            with self.subTest(name=name):
                proc = subprocess.run(["bash", "-n"], input=content, text=True, capture_output=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_networkmanager_privacy_defaults(self):
        cfg = heredoc("NETWORK_PRIVACY")
        parser = configparser.ConfigParser(interpolation=None)
        parser.read_string(cfg)
        self.assertEqual(parser["main"]["dns"], "systemd-resolved")
        self.assertEqual(parser["main"]["hostname-mode"], "none")
        self.assertEqual(parser["connectivity"]["enabled"], "false")
        conn = parser["connection"]
        expected = {
            "ipv4.dhcp-send-hostname": "false",
            "ipv6.dhcp-send-hostname": "false",
            "ipv4.dhcp-client-id": "stable",
            "ipv4.dhcp-iaid": "stable",
            "ipv6.dhcp-duid": "stable-uuid",
            "ipv6.dhcp-iaid": "stable",
            "ipv6.addr-gen-mode": "stable-privacy",
            "ipv6.ip6-privacy": "2",
            "connection.llmnr": "0",
            "connection.mdns": "0",
            "wifi.cloned-mac-address": "stable-ssid",
        }
        for key, value in expected.items():
            self.assertEqual(conn[key], value)
        self.assertEqual(parser["device"]["wifi.scan-rand-mac-address"], "yes")

    def test_resolved_privacy_defaults(self):
        cfg = heredoc("RESOLVER_PRIVACY")
        parser = configparser.ConfigParser(interpolation=None)
        parser.read_string(cfg)
        resolve = parser["Resolve"]
        self.assertEqual(resolve["LLMNR"], "no")
        self.assertEqual(resolve["MulticastDNS"], "no")
        self.assertEqual(resolve["DNSOverTLS"], "no")

    def test_zram_policy_is_bounded_and_not_over_tuned(self):
        cfg = heredoc("ZRAM")
        parser = configparser.ConfigParser(interpolation=None)
        parser.read_string(cfg)
        zram = parser["zram0"]
        self.assertEqual(zram["zram-size"], "min(ram / 2, 4096)")
        self.assertNotIn("compression-algorithm", zram)
        self.assertNotIn("swap-priority", zram)

    def test_firewall_default_policies(self):
        cfg = heredoc("NFT")
        self.assertIsNotNone(re.search(r"chain input\s*\{.*?policy drop;", cfg, re.S))
        self.assertIsNotNone(re.search(r"chain forward\s*\{.*?policy drop;", cfg, re.S))
        self.assertIsNotNone(re.search(r"chain output\s*\{.*?policy accept;", cfg, re.S))
        self.assertNotIn("tcp dport 22 accept", cfg)

    def test_low_risk_security_hardening(self):
        cfg = heredoc("SYSCTL")
        expected = {
            "kernel.dmesg_restrict = 1",
            "kernel.kptr_restrict = 2",
            "kernel.yama.ptrace_scope = 1",
            "kernel.randomize_va_space = 2",
            "fs.suid_dumpable = 0",
            "fs.protected_hardlinks = 1",
            "fs.protected_symlinks = 1",
        }
        self.assertTrue(expected <= set(cfg.splitlines()))
        self.assertNotIn("mitigations=off", TEXT)

    def test_boot_storage_and_crypto_decisions(self):
        self.assertIn("--new=1:0:+2GiB", TEXT)
        self.assertIn("--typecode=1:ef00", TEXT)
        self.assertIn("--typecode=2:8309", TEXT)
        self.assertIn("cryptsetup luksFormat --type luks2", TEXT)
        self.assertIn("--pbkdf argon2id", TEXT)
        self.assertIn("mkfs.ext4 -m 1 -L archroot", TEXT)
        self.assertIn("mount -o nosuid,nodev,noexec,fmask=0077,dmask=0077", TEXT)
        self.assertNotIn('mount -o noatime "/dev/mapper/$CRYPT_NAME"', TEXT)
        self.assertIn("grub-install --target=x86_64-efi", self.chroot)
        self.assertIn("linux-lts", TEXT)

    def test_secure_boot_is_explicitly_unsupported(self):
        self.assertIn("Disable Secure Boot first; this installer does not sign the boot chain.", TEXT)
        self.assertIn("Secure Boot disabled", TEXT)

    def test_nvidia_current_strategy_and_suspend_decision(self):
        self.assertIn("nvidia-open nvidia-open-lts nvidia-utils", TEXT)
        self.assertNotIn("nvidia-open-dkms", TEXT)
        self.assertNotIn("options nvidia_drm modeset=1 fbdev=1", TEXT)
        self.assertNotIn("nvidia_drm.modeset=1", TEXT)
        self.assertIn("systemctl disable nvidia-suspend.service nvidia-suspend-then-hibernate.service nvidia-hibernate.service nvidia-resume.service", self.chroot)
        self.assertIn("UseKernelSuspendNotifiers", self.doctor)

    def test_cpu_policy_is_adaptive_except_on_demand_gamemode(self):
        self.assertNotIn("skittles-performance.service", TEXT)
        self.assertNotIn("cpupower --cpu all frequency-set --governor performance", TEXT)
        self.assertIn("desiredgov=performance", heredoc("GAMEMODE"))
        self.assertIn("Gaming profile requires the performance governor for GameMode.", TEXT)
        self.assertNotIn("CPU governor: performance.", TEXT)

    def test_release_file_uses_runtime_version(self):
        self.assertIn("printf 'VERSION=%s\\nPROFILE=%s\\nDISCARDS=%s\\nBOOTLOADER=grub", self.chroot)
        self.assertIn('"$VERSION" "$PROFILE" "$ALLOW_DISCARDS" > /etc/skittles-release', self.chroot)
        self.assertNotRegex(self.chroot, r"VERSION=1\.0\.0(?:\n|$)")

    def test_doctor_has_required_release_diagnostic_areas(self):
        for heading in [
            "BOOT / SECURITY", "NVIDIA", "CPU", "STORAGE / ZRAM / TRIM",
            "NETWORK / PRIVACY", "FIREWALL", "FAILED SERVICES",
        ]:
            self.assertIn(heading, self.doctor)
        for token in [
            "Secure Boot disabled", "NVIDIA GPU responds", "zram swap active",
            "resolver points at systemd-resolved stub", "NetworkManager configuration parses",
            "Skittles firewall table loaded", "systemctl --failed",
        ]:
            self.assertIn(token, self.doctor)


class AuditRegressionTests(unittest.TestCase):
    def test_resolver_switch_happens_only_after_successful_chroot(self):
        # Run the real install_system function on ordinary temporary files.
        # Every privileged/storage command is replaced by a shell function.
        function = re.search(r"^install_system\(\) \{\n.*?^\}", TEXT, re.M | re.S).group(0)
        chroot = heredoc("CHROOT_SCRIPT")
        self.assertNotIn("ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf", chroot)
        for result in (0, 23):
            with self.subTest(chroot_exit=result), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                (root / "etc").mkdir()
                (root / "work").mkdir()
                (root / "work/pacman.conf").write_text("# fixture\n")
                resolver = root / "etc/resolv.conf"
                resolver.write_text("nameserver 192.0.2.1\n")
                body = function + f"""
set -Eeuo pipefail
MNT={shlex.quote(td)}
WORKDIR="$MNT/work"
EFI_MNT="$MNT/boot"
CRYPT_NAME=fictional
ROOT_PART=fictional
PACKAGES=()
USERNAME=fixture TIMEZONE=UTC LOCALE=C KEYMAP=us HOSTNAME=fixture
ALLOW_DISCARDS=0 PROFILE=minimal VERSION=test
USER_PASSWORD=synthetic-user ROOT_PASSWORD=synthetic-root
require_approved_plan() {{ :; }}
assert_target_binding() {{ :; }}
log() {{ :; }}
pacstrap() {{ :; }}
genfstab() {{ :; }}
write_chroot_script() {{ :; }}
cryptsetup() {{ [[ $1 != luksUUID ]] || printf '%s' 11111111-1111-1111-1111-111111111111; }}
blkid() {{ printf '%s' 22222222-2222-2222-2222-222222222222; }}
arch-chroot() {{
    [[ ! -L "$MNT/etc/resolv.conf" ]] || return 99
    cat >/dev/null
    return {result}
}}
sync() {{ :; }}
umount() {{ :; }}
install_system
"""
                proc = subprocess.run(["bash", "-c", body], text=True, capture_output=True)
                self.assertEqual(proc.returncode, result, proc.stderr)
                if result == 0:
                    self.assertTrue(resolver.is_symlink())
                    self.assertEqual(str(resolver.readlink()), "../run/systemd/resolve/stub-resolv.conf")
                else:
                    self.assertFalse(resolver.is_symlink())
                    self.assertEqual(resolver.read_text(), "nameserver 192.0.2.1\n")

    def test_partitioning_refuses_identity_change_after_wipe(self):
        proc = run_bash("""
set -Eeuo pipefail
require_approved_plan() { :; }
assert_target_binding() { :; }
assert_install_workspace() { :; }
assert_selected_drives() { :; }
section() { :; }
clear_disk() { WIPED=1; }
assert_same_disk() { [[ ${WIPED:-0} == 0 ]] || die 'identity changed'; }
sgdisk() { printf 'PARTITION_CALLED'; }
partprobe() { :; }
udevadm() { :; }
EFI_PART=/dev/FICTIONAL1 ROOT_PART=/dev/FICTIONAL2
DISK=/dev/FICTIONAL DISK_IDENTITY=fixture DISK_SIZE_BYTES=1
wipe_and_partition
""")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("identity changed", proc.stderr)
        self.assertNotIn("PARTITION_CALLED", proc.stdout)

    def test_doctor_failed_service_query_does_not_report_false_pass(self):
        doctor = heredoc("DOCTOR_SCRIPT")
        fragment = doctor.split("section 'FAILED SERVICES'\n", 1)[1]
        for rc, output, expected in [(1, "", "could not query"), (0, "", "PASS"), (0, "broken.service", "FAIL")]:
            with self.subTest(rc=rc, output=output):
                body = f"""
failures=0
pass() {{ printf 'PASS %s\\n' "$*"; }}
fail() {{ printf 'FAIL %s\\n' "$*"; failures=$((failures+1)); }}
systemctl() {{ printf '%s' {shlex.quote(output)}; return {rc}; }}
""" + fragment
                proc = subprocess.run(["bash", "-c", body], text=True, capture_output=True)
                self.assertIn(expected, proc.stdout)
                self.assertEqual(proc.returncode, 0 if rc == 0 and not output else 1)
                if rc:
                    self.assertNotIn("PASS", proc.stdout)

    def test_doctor_skips_wayland_check_in_console(self):
        doctor = heredoc("DOCTOR_SCRIPT")
        fragment = doctor.split('if [[ ${XDG_SESSION_TYPE:-} == wayland ]]', 1)[1].split("\n\nsection 'BOOT / SECURITY'", 1)[0]
        fragment = 'if [[ ${XDG_SESSION_TYPE:-} == wayland ]]' + fragment
        for session, expected in [("tty", "INFO"), ("", "INFO"), ("wayland", "PASS"), ("x11", "FAIL")]:
            with self.subTest(session=session):
                proc = subprocess.run(["bash", "-c", 'pass() { echo PASS; }; fail() { echo FAIL; }; info() { echo INFO; }; XDG_SESSION_TYPE=' + shlex.quote(session) + '\n' + fragment], text=True, capture_output=True)
                self.assertEqual(proc.stdout.strip(), expected)


if __name__ == "__main__":
    unittest.main()
