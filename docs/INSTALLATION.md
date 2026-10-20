# Installing and using Valtus

## 1. System requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Architecture | x86-64 (amd64) | x86-64 |
| RAM | 2 GB live; 2 GB installed | 4 GB+ |
| Disk | 2 GB for live media | 20 GB+ for installation (installer milestone) |
| CPU | 64-bit, PAE/NX capable | any 2012-era dual-core or newer |
| Firmware | BIOS (legacy) or UEFI | UEFI |
| Graphics | any VESA/DRM card (virtio-gpu fine) | Intel/AMD integrated |
| Network | not required for live boot; required for package ops | DHCP network |

## 2. Live credentials (fixed, documented)

The live session user is **valtus** with the password recorded in
`config/valtus.env` (default: `valtus`). This is displayed by the welcome
application at first login.

**Why a fixed password?** The project deliberately uses known live-session
credentials (env-file pattern: one authoritative config file, no inline
values anywhere). A live ISO has no network services listening and is
intended for local use; the trade-off is documented in
[ARCHITECTURE.md §5.1](ARCHITECTURE.md). An *installed* Valtus system (when the
installer lands) will ask you to choose a strong password; the password
policy enforces ≥10 characters with ≥3 character classes.

## 3. Write the ISO to a USB stick

Linux/macOS:

```bash
lsblk                      # identify the target device, e.g. /dev/sdb
sudo dd if=valtus-0.1.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
```

Windows: use Rufus or balenaEtcher in "DD image" mode. Verify downloads
separately with the shipped SHA-256 checksum:

```bash
sha256sum valtus-0.1.0-amd64.iso        # must match releases/valtus-0.1.0-amd64.iso.sha256
```

Disk-space note: the ISO is ~1.93 GiB and the whole project budget stays far
below 60 GB.

## 4. Boot

1. Insert the medium and boot. On UEFI systems pick the "UEFI: " boot device
   or use the firmware boot menu. Legacy BIOS boots automatically.
2. GRUB menu: choose **Valtus 0.1.0 — live session** (or *safe graphics* if the
   screen stays black).
3. SDDM login: user `valtus`, password from §2.
4. The welcome application starts automatically.

## 5. First login checklist

| Task | How |
|---|---|
| Connect to Wi-Fi/Ethernet | KDE tray → network applet (NetworkManager) |
| Adjust sound | tray volume applet (PipeWire) |
| Install software | *Valtus* → Discover, or Konsole: `sudo apt install ...` |
| Update the system | On the live session updates run when you choose to; installed systems update automatically via unattended-upgrades |
| Lock session | Meta+L, or the system menu → Lock |

> **Live-session note:** apt inside a live session works while the network is
> available, but changes live only in RAM. Persist changes by installing
> (installer milestone) or by carrying a persistent USB overlay (not part of
> 0.1.0).

## 6. sudo note

The live user is a member of `sudo`. Unlike typical live images, Valtus
**requires the sudo password** — this is intentional (see ARCHITECTURE.md
§5.2). Use the documented live password when prompted.

## 7. Disk installation (not in 0.1.0)

A disk installer is the next milestone. Until then:

- Any standard Linux installer workflow for this base (Ubiquity/Calamares
  flows) applies.
- Manual install path: copy the live system content and set up GRUB with
  `grub-install` from a live session — standard practice, not automated yet.
