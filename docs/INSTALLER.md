# Valtus installer — architecture & testing

## 1. Approach

Valtus uses **Calamares 3.3** (noble, `calamares` 3.3.5-0ubuntu4) — an
established, distribution-independent installer framework — rather than a
custom partitioning tool. The exact upstream components used:

| Component | Package | Role |
|---|---|---|
| Installer front-end | `calamares` | Guided install flow, slideshow, branding |
| Partitioning | `libkpmcore12` (KDE Partition Manager Core) | Partition operations |
| OS detection | `os-prober` | Existing-system detection for dual boot |
| Bootloader | `grub2-common`, `grub-efi-amd64-signed`, `shim-signed` (in the image) | GRUB + secure-boot-capable chain |
| Shell helpers | `util-linux-extra` | chattr etc. used by the unpack step |

The launcher `/usr/bin/valtus-install` (from `scripts/valtus-install`):
- refuses to run as root (the installer uses polkit for privilege),
- applies the Valtus branding (`-b valtus`) and configuration (`/etc/calamares`),
- stores no credentials — the users module asks the operator for the primary
  account username and password.

## 2. Files

| Path | Purpose |
|---|---|
| `/etc/calamares/settings.conf` | Module order + global settings (locale, keyboard, storage minimums, hostname policy) |
| `/etc/calamares/modules-users.conf` | No empty passwords, default groups, no autologin |
| `/etc/calamares/modules-bootloader.conf` | UEFI GRUB + fallback entry named **Valtus** |
| `/etc/calamares/modules-grubcfg.conf` | Install `/boot/grub/grub.cfg` on the target |
| `/etc/calamares/modules-fstab.conf` | Generate `/etc/fstab` (ext4 by default) |
| `/etc/calamares/modules-packages.conf` | No additional downloads — the live filesystem contains everything |
| `/usr/share/calamares/branding/valtus/` | `branding.desc`, `valtus.css`, logo, sidebar |
| `/usr/share/applications/valtus-installer.desktop` | Menu entry (autostarts nothing) |

Branding keys (from `branding.desc`): `windowTitle: "Install Valtus"`,
`productName: "Valtus"`, `version: "0.1.0 (granite)"`,
`bootloaderEntryName: "Valtus"`.

## 3. Install flow

1. Live session boots (GRUB → casper live).
2. User chooses **Install Valtus** (menu or `valtus-install`).
3. Calamares pages: language/keyboard → disk & partitions → primary account
   (user-chosen credentials; hostname from the username) → summary → install.
4. On completion the machine reboots; GRUB on the target disk's ESP boots the
   installed system (GRUB entry named **Valtus**).

## 4. Automated test

`scripts/test_installer.sh`:

1. Creates a **disposable 64 GiB qcow2** disk (never touches the host).
2. Boots the ISO with the disk attached; logs in as the documented live user.
3. Verifies the installer and branding are present (`/usr/bin/valtus-install`,
   `/usr/share/calamares/branding/valtus/branding.desc`).
4. Runs the install, waits for completion, powers off.
5. Reboots with the **ISO detached** (boot from disk only).
6. Verifies: the installed system boots, the user's own account works,
   the Valtus branding is present, systemd is up, then powers off.

Evidence (screenshots + serial logs) is written to
`logs/installer-test-<timestamp>/`.

## 5. Known limitations

- The installer writes **MBR or UEFI GRUB**; Secure Boot verification of the
  installed system has not been tested (shim-signed packages are shipped).
- Encryption (LUKS) is offered by Calamares' partition page but is not
  enabled by default and is untested in this milestone.
- Calamares' `netinstall`-style package fetching is disabled: the installed
  system is a copy of the live filesystem, so all packages are already
  present.
