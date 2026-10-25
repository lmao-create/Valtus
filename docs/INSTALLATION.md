# Installing and using Valtus

## 1. System requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Architecture | x86-64 (amd64) | x86-64 |
| RAM | 2 GB live; 2 GB installed | 4 GB+ |
| Disk | 2 GB for live media | **20 GB+ for installation** |
| CPU | 64-bit, PAE/NX capable | any 2012-era dual-core or newer |
| Firmware | BIOS (legacy) or UEFI | **UEFI** (the installer writes an ESP) |
| Graphics | any VESA/DRM card (virtio-gpu fine) | Intel/AMD integrated |
| Network | not required for live boot; required for updates | DHCP network |

## 2. Writing the ISO

Linux/macOS:
```bash
lsblk                      # identify the target device, e.g. /dev/sdb
sudo dd if=valtus-0.1.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
sync
```
Windows: Rufus or balenaEtcher in **DD image** mode. Verify with:
```bash
sha256sum -c valtus-0.1.0-amd64.iso.sha256
```

## 3. Live session

Boot from the ISO/USB, choose **Valtus — live session** (or *safe graphics* if the
screen is black). Log in at SDDM with the documented live credentials:
**user `valtus`, password `valtus`** (fixed demo credentials for the live
session only — see [ARCHITECTURE.md §5.1](ARCHITECTURE.md)).

The welcome application starts automatically.

## 4. Installing to disk

1. Boot the live session.
2. Start **Install Valtus** from the application menu (or run `valtus-install`).
3. The installer (Calamares, Valtus-branded) walks through:
   - select language, keyboard
   - **partition** — choose the disk and layout (erases the disk; or manual)
   - **create your account** — you choose the username and password (Valtus
     does not default or reuse the live password), and the hostname
   - **review and install** — writes ext4, sets up GRUB in the ESP
4. Reboot and remove the medium. The installed system boots into Valtus with
   your account, Valtus theme, and the full desktop.

> **Installed systems are not covered by the live-session credentials.** You
> choose your own password during installation (PAM policy: ≥10 characters,
> 3 character classes).

## 5. First login checklist

| Task | How |
|---|---|
| Connect to Wi-Fi/Ethernet | KDE tray → NetworkManager applet |
| Sound | tray volume applet (PipeWire) |
| Install software | Discover, or `sudo apt install …` |
| Security | KDE tray → firewall (UFW); Valtus Security for antivirus |
| Updates | installed systems update automatically (unattended-upgrades) |
| Lock session | Meta+L |

## 6. Verify a Valtus Security install

```bash
valtus-security status          # honest component status
valtus-security scan ~          # on-demand scan (needs signatures)
valtus-security --version
```

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| Black screen after GRUB | pick *safe graphics* (nomodeset) |
| Installer absent in the menu | install with `sudo apt install valtus-installer` or upgrade the image |
| Boots back to live after reboot | remove the USB/ISO and check the firmware boot order |
| See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | general issues |
