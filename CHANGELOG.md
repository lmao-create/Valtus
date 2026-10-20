# Valtus changelog

All notable changes to the Valtus project are recorded here. The format is
based on Keep a Changelog, and the project uses semantic versioning.

## [0.1.0] — 2026-10-20 — first development release candidate

### Added
- Scripted, reproducible build of an Ubuntu 24.04 LTS (noble) amd64 live ISO:
  `scripts/build.sh` (debootstrap → package install → customization →
  squashfs → GRUB hybrid ISO). Cached stages (01-bootstrap → 02-packages →
  03-customized) allow `--from 3` config-only iteration in ~7 minutes.
- Valtus identity configuration (`config/distro.conf`): name, version 0.1.0,
  codename granite, hostname, wallpaper/logo paths, theme, default apps.
- Credentials env-file pattern (`config/valtus.env`, optional gitignored
  `config/valtus.local.env`); no password appears inside any script.
- Original branding (SVG sources, rendered to PNG at build time): logo,
  emblem, chevron wallpaper (1920×1080 + 3840×2160), ValtusDark Plasma color
  scheme, desktop look-and-feel package, SDDM login background.
- Desktop defaults shipped via `/etc/skel`: Noto Sans 10pt fonts, ValtusDark
  scheme, bottom panel (kickoff launcher, icon-only task manager, system tray,
  digital clock), Konsole "Valtus" profile, Dolphin full-path location bar.
- Welcome application (`scripts/valtus-welcome.py`, PyQt6) with quick
  launchers and the documented live credential, autostarted at first login.
- Security hardening: locked root account, password-required sudo (casper's
  NOPASSWD grant removed), no autologin into SDDM, `ufw` default-deny incoming
  enabled at boot, unattended security upgrades, AppArmor, sysctl hardening
  set, PAM password quality policy (minlen 10, 3 classes).
- Live-session credentials provisioning: casper-bottom initramfs hook +
  authoritative `valtus-live-credentials.service` systemd unit
  (`ConditionUser` keeps it inert on installed systems).
- Tooling: `scripts/validate.sh` (static ISO validation), `scripts/checksums.sh`,
  `scripts/test_vm.sh` (QEMU/KVM automated tests with serial logging, monitor
  screendumps, in-guest checks, RESULTS.txt), `tests/smoke_test.sh`,
  `Makefile` convenience targets.
- Documentation: README, docs/{BUILD,TESTING,ARCHITECTURE,INSTALLATION,
  TROUBLESHOOTING,ENVIRONMENT}, THIRD-PARTY-LICENSES.md.

### Fixed
- World-writable/uid-1000 system files (DrvFs artifact of building against
  the `/mnt/c` project drive): build now normalizes ownership and permissions
  for all Valtus-added paths and the rootfs root directory.
- usrmerge-safe `/etc/os-release` handling (no duplicate `cp`).
- ISO validator EFI path casing (grub-mkrescue writes lowercase Rock Ridge
  `/efi/...`).
- VM harness: `wait_pat` shell `local` evaluation order; boot entry
  navigation; guarded cleanup (only the dedicated `/root/valtus-vm-test-*`
  work directory is ever removed).
- KDE Plasma 6 package names for noble (`plasma-workspace-wayland`,
  `kde-spectacle`).

### Known limitations (see docs/TESTING.md)
- No disk-installation workflow yet (installer is a later milestone); the
  initial milestone is a live image.
- KDE Wallet first-login prompt is not pre-seeded.
- casper disables unattended-upgrades/update-notifier inside the live
  session (documented; installed systems keep them enabled).
- VirtualBox host testing not available on the build host this milestone.
- No full-disk-encryption or Secure Boot signing yet.

## [Unreleased]

- Installer milestone (calamares-based, Valtus-branded) and installation
  tests to a disposable disk.
