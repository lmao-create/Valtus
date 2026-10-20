# Valtus

**Valtus** is a professional, general-purpose Linux distribution for desktop
computers, built from an Ubuntu LTS base with a KDE Plasma desktop, an
original visual identity, and a security-first design.

- **Base:** Ubuntu 24.04 LTS (noble), amd64, supported upstream kernel (6.8.0-147-generic)
- **Desktop:** KDE Plasma 6 (Wayland default, X11 fallback), original Valtus theme
- **Build:** fully scripted and reproducible (debootstrap → apt → squashfs →
  GRUB hybrid ISO), no hand-crafted steps
- **Security:** locked root, password-required sudo, firewall default-deny
  incoming, unattended security upgrades, AppArmor, kernel hardening backend
- **Licensing:** build scripts docs MIT; included system software retains
  upstream licenses — see [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md)

> **Status:** version 0.1.0 *development* release candidate. A live-session
> image is the current milestone; the disk installer is planned next. See
> [docs/TESTING.md](docs/TESTING.md) for what has been tested and what has
> not.

## Documentation

| Document | Contents |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Design, security model, boot flow, package rationale |
| [docs/BUILD.md](docs/BUILD.md) | Reproducing the ISO (environment setup + exact commands) |
| [docs/TESTING.md](docs/TESTING.md) | Test matrix, results, VM configuration, evidence |
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | System requirements, live credentials, install workflow |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common problems and fixes |
| [docs/ENVIRONMENT.md](docs/ENVIRONMENT.md) | Build-host environment report |
| [CHANGELOG.md](CHANGELOG.md) | Version history and known limitations |

## Repository layout

```
.
├── Makefile                  make build / validate / checksum / smoke / vmtest
├── README.md  LICENSE  CHANGELOG.md  THIRD-PARTY-LICENSES.md
├── config/
│   ├── distro.conf           identity, versions, desktop, branding defaults
│   ├── valtus.env            credentials & sensitive defaults (env-file)
│   ├── packages/             base.txt desktop.txt security.txt
│   ├── desktop/              skel defaults, look-and-feel, wallpaper meta
│   └── rootfs/               system overlay copied into the image (/etc ...)
├── branding/
│   ├── logos/                valtus-logo.svg, valtus-emblem.svg (+ rendered PNG)
│   ├── wallpapers/           valtus-wallpaper.svg (+ rendered PNG)
│   └── themes/               ValtusDark.colors
├── scripts/
│   ├── build.sh              reproducible ISO pipeline (staged, cached)
│   ├── validate.sh           static ISO checks (size, sha256, structure)
│   ├── checksums.sh          release SHA-256 sidecars
│   ├── test_vm.sh            QEMU/KVM automated tests + evidence
│   ├── valtus-welcome.py     welcome application (PyQt6)
│   └── dev/                  development helpers (recovery, inspection)
├── tests/smoke_test.sh       static repository checks (no root needed)
├── docs/                     all documentation
├── logs/                     build logs and VM test evidence (not committed)
└── releases/                 built ISOs + sha256 + manifest (not committed)
```

## Quick start

Requires a WSL2 Linux environment (or any Debian-based x86-64 host) with the
packages listed in `docs/BUILD.md`.

```bash
# 1. one-time host setup (Debian WSL)
wsl -d Debian -u root -- make deps

# 2. build the ISO (runs as root inside WSL, ~40-70 min first time)
wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/build.sh'

# 3. validate + boot test
wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/validate.sh' \
  '/mnt/c/Users/hp/Desktop/Custom OS/releases/valtus-0.1.0-amd64.iso'
wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/test_vm.sh' \
  '/mnt/c/Users/hp/Desktop/Custom OS/releases/valtus-0.1.0-amd64.iso'
```

Result: `releases/valtus-0.1.0-amd64.iso` (+ `.sha256`, `.manifest.txt`,
`.build.log`). Boot either BIOS or UEFI. Full instructions and results:
[docs/BUILD.md](docs/BUILD.md), [docs/TESTING.md](docs/TESTING.md).

## Current release

| | |
|---|---|
| ISO | `releases/valtus-0.1.0-amd64.iso` |
| Size | 2,067,904,512 bytes (~1.93 GiB) |
| SHA-256 | `fddbbdd7408cf0f78a60032afd7ff0facc30307033929875719bdec35afd69f6` |
| Kernel | 6.8.0-147-generic (Ubuntu noble) |
| Packages | 1538 |

(Checksums and exact values are also in the release `.manifest.txt`.)

## Writing the ISO to a USB stick (Linux/macOS)

```bash
sudo dd if=valtus-0.1.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Live login

User **valtus**, password **valtus** — fixed, documented live-only credentials
(threat model: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) §5.1).

## Project identity

Name **Valtus**, version 0.1.0, codename **granite**, live user **valtus**.
All of it is configurable in `config/distro.conf`; credentials live only in
`config/valtus.env`. Valtus is an independent project; it is not affiliated
with Canonical Ltd. (Ubuntu) or the KDE project.
