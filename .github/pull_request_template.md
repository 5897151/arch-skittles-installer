## Summary

Describe the smallest useful change and why it is needed.

## Safety impact

- [ ] This does not weaken target-disk selection, exact confirmation, plan binding, identity revalidation, or extra-wipe ordering.
- [ ] Any change touching disk selection/wipe/partition/mount/cryptsetup has focused regression tests.
- [ ] No confirmation-bypass, unattended force flag, default target, automatic unrelated unmount, or silent fallback disk was added.

## Security / privacy / boot impact

- [ ] I called out changes touching cryptsetup, GRUB/Secure Boot, sudo, nftables, resolver/network identity, NVIDIA boot/suspend behavior, or root-owned generated scripts.
- [ ] Security/privacy claims are supported by primary/upstream documentation where practical.
- [ ] Logs/fixtures contain no passwords, Wi-Fi secrets, drive serials, API keys, or personal identifiers.

## Performance impact

- [ ] No performance default changed; or
- [ ] The PR includes a hypothesis, repeatable measurement method, baseline/results, target workload, and downsides.

## Validation

- [ ] `bash -n skittles-installer.sh`
- [ ] `shellcheck skittles-installer.sh`
- [ ] `python3 -m unittest discover -s tests -v`
- [ ] `git diff --check`
- [ ] Required real-hardware checks are listed when automation/VMs cannot establish correctness.
