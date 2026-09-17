# Recovery from a Current Arch ISO

These instructions assume the installed machine does not boot. They are intentionally explicit because guessing a device path during recovery can destroy data.

> [!CAUTION]
> Never copy a device name from an example. First identify the actual partitions with `lsblk`. Placeholders such as `/dev/REPLACE_WITH_ACTUAL_LUKS_ROOT_PARTITION` and `/dev/REPLACE_WITH_ACTUAL_EFI_PARTITION` are not commands you can run unchanged.

## 1. Boot and identify the installed disk safely

Boot a current official Arch installation ISO in UEFI mode. Do **not** run `skittles-installer.sh`; recovery is manual and nondestructive unless you explicitly run a modifying command. This recovery flow was re-audited against current `arch-chroot`, mkinitcpio/systemd-initramfs, GRUB, and Arch system-maintenance guidance, but the owner deferred the physical recovery drill for v1.0.0. No recovery-execution PASS is claimed.

Inventory storage:

```bash
lsblk -e7 -o NAME,PATH,SIZE,TYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS,MODEL,SERIAL,TRAN
```

On a normal SKITTLES target you should find one internal disk with a roughly 2 GiB FAT32 EFI partition and a second partition whose type is `crypto_LUKS`. Match size/model/serial to the physical machine before continuing.

For the rest of this document, replace:

- `/dev/REPLACE_WITH_ACTUAL_LUKS_ROOT_PARTITION` with the identified `crypto_LUKS` partition;
- `/dev/REPLACE_WITH_ACTUAL_EFI_PARTITION` with the identified FAT32 EFI partition.

Do not use the whole-disk path for either placeholder.

## 2. Optional: back up the LUKS header first

A LUKS-header backup can recover metadata damage, but it must be stored on a **different, trusted, mounted device**. Verify the destination mount with `findmnt` before writing it.

```bash
cryptsetup luksDump /dev/REPLACE_WITH_ACTUAL_LUKS_ROOT_PARTITION
findmnt /run/media/REPLACE_WITH_TRUSTED_BACKUP_MOUNT
cryptsetup luksHeaderBackup \
  /dev/REPLACE_WITH_ACTUAL_LUKS_ROOT_PARTITION \
  --header-backup-file /run/media/REPLACE_WITH_TRUSTED_BACKUP_MOUNT/skittles-luks-header.img
chmod 600 /run/media/REPLACE_WITH_TRUSTED_BACKUP_MOUNT/skittles-luks-header.img
```

Never store the only header backup on the same disk it protects. Protect the backup like sensitive encryption metadata.

## 3. Unlock and mount

```bash
cryptsetup open /dev/REPLACE_WITH_ACTUAL_LUKS_ROOT_PARTITION skittles-root
mount /dev/mapper/skittles-root /mnt
mkdir -p /mnt/boot
mount /dev/REPLACE_WITH_ACTUAL_EFI_PARTITION /mnt/boot
findmnt -T /mnt
findmnt -T /mnt/boot
```

Before chrooting, confirm `/mnt` is ext4 from `/dev/mapper/skittles-root` and `/mnt/boot` is the expected vfat partition.

## 4. Establish networking when package repair is needed

Connect the live ISO first. Verify:

```bash
getent hosts archlinux.org
```

Do not manually populate `/mnt/run` or replace the installed resolver symlink before entering the chroot. Current `arch-chroot` sets up the required API filesystems and temporarily supplies the live environment's resolver to the chroot. This preserves live-ISO DNS for package repair without rewriting the installed resolver configuration.

## 5. Enter the installed system

```bash
arch-chroot /mnt
```

If DNS unexpectedly fails inside the chroot, exit and fix networking/resolution in the live ISO first instead of inventing a second resolver layout under `/mnt/run`.

Inside the chroot, inspect the recorded release and package state:

```bash
cat /etc/skittles-release
pacman -Q linux linux-lts nvidia-open nvidia-open-lts nvidia-utils grub mkinitcpio
```

## 6. Update or reinstall core boot/graphics packages

If network access works and package repair is needed, use a **full** upgrade transaction:

```bash
pacman -Syu linux linux-lts linux-firmware intel-ucode \
  nvidia-open nvidia-open-lts nvidia-utils grub efibootmgr mkinitcpio cryptsetup
```

Do not perform partial Arch upgrades.

Confirm both NVIDIA module trees exist:

```bash
for d in /usr/lib/modules/*; do
  [ -f "$d/pkgbase" ] || continue
  case "$(cat "$d/pkgbase")" in
    linux|linux-lts)
      modinfo -k "${d##*/}" nvidia
      modinfo -k "${d##*/}" nvidia_drm
      ;;
  esac
done
```

## 7. Rebuild initramfs

Verify the installed hooks still use `sd-encrypt`, then rebuild both presets:

```bash
grep '^HOOKS=' /etc/mkinitcpio.conf
mkinitcpio -P
```

Expected SKITTLES hooks include `systemd` and `sd-encrypt`.

## 8. Repair GRUB

With the EFI partition mounted at `/boot`:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=SKITTLES --recheck
grub-install --target=x86_64-efi --efi-directory=/boot --removable --no-nvram --recheck
grub-mkconfig -o /boot/grub/grub.cfg
grub-script-check /boot/grub/grub.cfg
grep -n 'linux-lts' /boot/grub/grub.cfg
```

The second command recreates the fallback `EFI/BOOT/BOOTX64.EFI` path. If efivars are unavailable in the ISO boot, the fallback path can still be repaired, but creating/updating the normal firmware entry may require rebooting the ISO in proper UEFI mode with efivars exposed.

## 9. Inspect logs and failed services

When diagnosing the previous boot from the chroot:

```bash
journalctl -b -1 -p warning..alert
journalctl -b -1 -u sddm -u NetworkManager -u systemd-resolved -u nftables
```

After a successful boot, also run:

```bash
skittles-doctor
sudo skittles-doctor
systemctl --failed
```

## 10. Prefer `linux-lts` when the main kernel is broken

If GRUB itself works, the least invasive recovery is often to select **Advanced options for Arch Linux** and boot the `linux-lts` entry. Once logged in, perform a normal full upgrade/reinstall and rebuild initramfs/GRUB as needed.

Do not rerun the installer as a repair action. It is destructive.

## 11. Exit and close safely

Leave the chroot, then unmount only the recovery mounts you created:

```bash
exit
sync
umount /mnt/boot
umount /mnt
cryptsetup close skittles-root
```

Check that the mapping is gone before rebooting:

```bash
lsblk
ls /dev/mapper
```

If an unmount reports busy, do not use a blind force option. Find the process or shell still using the mount, close it, and retry.
