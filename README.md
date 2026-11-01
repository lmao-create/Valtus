# Valtus 0.1.0 "granite" — Development Preview

**A professional, security-focused desktop Linux distribution — built on Ubuntu LTS with KDE Plasma.**

> ⚠️ This is a **development preview** (0.1.0), not a stable release.
> It is a fully working **live** system. Disk installation is not yet enabled — see below.

---

## What Valtus is

Valtus is an independent Linux distribution for desktop computers, built from an
Ubuntu 24.04 LTS (noble) base with the KDE Plasma 6 desktop. It has its own
visual identity — original logo, wallpaper, and color scheme — and ships with
**Valtus Security**, a built-in ClamAV-based antivirus.

## System requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Architecture | x86-64 (amd64) | x86-64 |
| RAM | 2 GB | 4 GB+ |
| Disk space | 2 GB (live media) | 20 GB+ (installation) |
| Firmware | BIOS or UEFI | UEFI |
| Graphics | any VESA/DRM card | modern Intel/AMD GPU |

## Further instructions

Full documentation is in the **`docs/` folder**:

| Document | What's inside |
|---|---|
| `docs/INSTALLATION.md` | Step-by-step live boot, disk installation, and first-login setup |
| `docs/BUILD.md` | How to rebuild the ISO from scratch, dependencies, reproducibility |
| `docs/ARCHITECTURE.md` | System design, boot flow, and the security model |
| `docs/TESTING.md` | What was tested, results, and known limitations |
| `docs/INSTALLER.md` | Installer status and the remaining work |
| `docs/ENVIRONMENT.md` | The host environment Valtus was built on |
| `docs/ANTIVIRUS-INTEGRATION.md` | Valtus Security packaging and verification |
| `THIRD-PARTY-LICENSES.md` | Full component licensing and attribution |
| `CHANGELOG.md` | Version history |

## Download

| File | Size | SHA-256 |
|---|---|---|
| `valtus-0.1.0-amd64.iso` | 2,118,694,912 B (~1.97 GiB) | `783d4923133d262577dd3ffa97c4e4ae98c406a6d4038c3ea83e308261039dae` |

Verify before use:

```bash
sha256sum -c valtus-0.1.0-amd64.iso.sha256
```

## Live login

User **`valtus`**, password **`valtus`** — fixed, documented, live-session-only
credentials (see *Security* below for why this is acceptable here and not for
an installed system).

---

## ✅ What works

| Area | Status |
|---|---|
| **Boot (Live)** | ✅ Verified in QEMU/KVM and VirtualBox. GRUB → Linux 6.8.0 → live desktop. |
| **Login screen** | ✅ SDDM with Valtus wallpaper/theme. |
| **Desktop** | ✅ KDE Plasma 6, Wayland, ValtusDark color scheme, bottom panel (launcher, taskbar, system tray, clock). |
| **Live session** | ✅ Logs in with the documented credentials; welcome app opens at first login. |
| **Networking** | ✅ NetworkManager (wired), DHCP, DNS verified in-VM. |
| **Package management** | ✅ `apt` works: `apt-get update` and installing a package verified from inside the live system. |
| **Applications** | ✅ Konsole, Dolphin, Kate, Okular, Falkon, VLC, Ark, Spectacle, Plasma Discover, System Settings, KInfoCenter, Plasma System Monitor, KCalc. |
| **Security** | ✅ Root account locked, password-required sudo, firewall active by default, automatic security updates enabled, AppArmor active, kernel hardening sysctls. |
| **Antivirus** | ✅ Valtus Security installed; EICAR test file detected; signatures update (3.6M). |
| **Shutdown** | ✅ Shuts down cleanly. |
| **Build reproducibility** | ✅ One command rebuilds the entire ISO from config. |

## ❌ What does not work yet

| Area | Status |
|---|---|
| **Disk installation** | ❌ **Not available.** The installer is packaged and branded but its configuration does not yet start. See below. |
| **Installer branding** | ❌ Ships with the app, but since the installer doesn't start, this is untested. |
| **Bluetooth / Wi-Fi** | ⚠️ Untested in the VM environment. |
| **Printers / scanners** | ⚠️ Untested. |
| **Secure Boot, LUKS encryption** | ⚠️ Untested. |
| **Performance tuning** | ⚠️ Untuned (no tuning applied yet). |

---

## How to install Valtus to your disk

> The graphical installer is **not functional in 0.1.0**. It appears in the menu
> but will fail to start. These are the two methods that do work.

### Option 1 — Risk-free: boot and test first (recommended for now)

Burn the ISO to a USB stick and boot it — everything works from USB without
touching your disk:

```bash
# Linux / macOS
sudo dd if=valtus-0.1.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
```
Windows: use Rufus or balenaEtcher in **DD image** mode.

### Option 2 — Manual installation onto your disk (advanced)

This copies the live system to your disk and installs GRUB. **Back up first —
this erases the target disk.**

```bash
# Boot the ISO, log in as valtus / valtus
sudo fdisk -l                       # find your disk, e.g. /dev/sdX — then reboot after partitioning
sudo mkfs.ext4 /dev/sdX1            # root partition (make an ESP first for UEFI)
sudo mount /dev/sdX1 /mnt           # ESP: mount at /mnt/boot/efi instead

# Copy the live system (excluding virtual filesystems)
sudo rsync -aAXH --exclude={/dev/*,/proc/*,/sys/*,/tmp/*,/run/*,/mnt/*,/cdrom/*} / /mnt/

for d in dev proc sys run; do sudo mount --bind /$d /mnt/$d; done
sudo chroot /mnt

grub-install /dev/sdX               # UEFI: grub-install --efi-directory=/boot/efi
update-grub
exit && sudo reboot
```

For a UEFI system, create a 512 MB EFI System Partition (FAT32) mounted at
`/mnt/boot/efi` before `grub-install --efi-directory=/boot/efi`.

### Option 3 — Wait for 0.2.0

A one-click graphical installer is the top priority of the next release.

---

## Credits & attribution

Valtus is only possible because of the free/open-source software it is built
from. Full details in `THIRD-PARTY-LICENSES.md`.

| Component | Author/Project | License |
|---|---|---|
| Ubuntu 24.04 LTS (base system) | Canonical Ltd. and contributors | GPL/LGPL/MIT/BSD (see package licenses) |
| KDE Plasma 6 desktop | KDE community | GPL/LGPL |
| Qt libraries | The Qt Company / Qt Project | LGPL/GPL |
| Linux kernel | Linus Torvalds and contributors | GPL v2 |
| casper (live boot), GRUB, systemd, NetworkManager, PipeWire | respective projects | GPL/LGPL/BSD |
| ClamAV (antivirus engine) | Cisco Systems, Inc. / ClamAV project | GPL v2 |
| Noto fonts | Google | SIL OFL 1.1 |
| Valtus original branding, build scripts, docs | **Valtus project** | MIT / CC0 |

**"Ubuntu" is a registered trademark of Canonical Ltd.** and **"KDE" is a
trademark of KDE e.V.** Valtus is an independent distribution. It is **not
affiliated with, endorsed by, or sponsored by Canonical Ltd., the KDE
community, the Qt Company, or any other upstream project.**

## A note on how Valtus was built

Valtus was **vibe coded** — developed with an AI coding assistant rather than
by a traditional engineering team. The scripts, configuration, branding, and
documentation were produced conversationally, iteratively, and with
machine assistance. It is an independent hobby project, not a commercially
backed or professionally audited distribution; treat it accordingly.

What that means in practice: the build is reproducible and the ISO works, but
**the quality assurance is one enthusiast plus automated tests, not a
professional QA organization.** Report issues rather than assuming correctness.

## Security note

- No SSH server is installed; the firewall blocks incoming connections.
- Root login is disabled; admin tasks run through `sudo` with a password.
- The live password is fixed and documented **by design for a live session
  only** (the live ISO has no network services; root is locked). A fixed
  password would be a serious weakness on a multi-user server — Valtus is a
  desktop distribution.
- An installed system (when available) will ask you to choose your own
  password.
- No telemetry, accounts, cloud services, or data collection are included.

## License

Original Valtus code (build scripts, branding, docs): MIT — see `LICENSE`.
Third-party components retain their own licenses — see
`THIRD-PARTY-LICENSES.md`.
