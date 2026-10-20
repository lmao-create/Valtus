# Environment Inspection — Phase 1 Findings

Inspected: 2026-10-19/20 (before and during build work).

## Host

| Item | Value |
|---|---|
| Operating system | Microsoft Windows 11 Home Single Language, build 26200 |
| Architecture | 64-bit (amd64) |
| CPU | 11th Gen Intel Core i3-1115G4 @ 3.00GHz — 2 cores / 4 threads |
| RAM | 8 GB total (~1.6 GB free at inspection; WSL VM allocated 3.7 GB) |
| Disk (C:) | 310 GB used, **168 GB free** |
| Hypervisor | Present (`HypervisorPresent: True`) — Hyper-V stack active |

## Build environment

| Item | Value |
|---|---|
| WSL | Installed, version 2 |
| Distro | Debian 13.5 (trixie), kernel 6.18.33.2-microsoft-standard-WSL2 |
| WSL filesystem | ext4 virtual disk, ~955 GB available |
| Nested virtualization | `/dev/kvm` present in WSL — KVM acceleration available |
| Root access in WSL | `wsl -d Debian -u root` works without password (documented WSL mechanism) |
| Network | OK — ~25 ms RTT to Debian mirror; Ubuntu archive reachable |

## Tool availability

| Tool | Windows host | Debian WSL |
|---|---|---|
| Git | 2.55.0.windows.3 ✔ | installed ✔ |
| QEMU | not installed | installed via apt (`qemu-system-x86`, KVM) |
| VirtualBox | not installed | n/a |
| debootstrap / squashfs-tools / xorriso | n/a | installed via apt ✔ |
| grub-mkrescue (BIOS+UEFI) | n/a | `grub-pc-bin` + `grub-efi-amd64-bin` + `mtools` ✔ |
| rsvg-convert (branding render) | n/a | installed via apt ✔ |

## Decisions

1. **Build inside Debian WSL2** — chroot/debootstrap do not work on the Windows
   filesystem (`/mnt/c`, DrvFs); they require real Linux semantics. Source of
   truth lives in the Windows workspace; build execution happens in the WSL
   ext4 filesystem; final artifacts are copied back to `releases/`.
2. **Build method: scripted debootstrap of Ubuntu 24.04 LTS (noble)** instead of
   Cubic. Cubic requires a desktop Linux host and interactive GUI steps — not
   suitable for this Windows/WSL environment and not reproducible. A scripted
   pipeline gives full reproducibility, produces a small ISO (~1.9 GiB), and
   verifies every package through Ubuntu's GPG-signed archive.
3. **VM testing: QEMU/KVM inside WSL2** (headless, serial console logging +
   QEMU monitor `screendump` for visual evidence). VirtualBox is not installed
   on the Windows host; nested KVM is available and faster than TCG.
4. **Size policy** — user budget is 50–60 GB total; the ISO soft limit is set
   to 4 GiB (see `ISO_SIZE_LIMIT_BYTES` in `config/distro.conf`); the actual
   ISO is ~1.93 GiB.

## Constraints / risks

- **RAM is tight** (8 GB host, 3.7 GB in WSL). VM tests run with 2 GB guest RAM.
- **DrvFs artifacts**: files on `/mnt/c` are uid 1000 / mode 777; the build
  normalizes ownership+permissions of all Valtus-added paths before packaging
  (found in build #1, fixed in build #2).
- Building on Windows without WSL is not viable for chroot-based ISO assembly.
