# Third-party licensing and attribution

Valtus is a Linux distribution assembled from free and open-source software.
Building and distributing Valtus copies and modifies none of the upstream
trademarks; this file records the provenance of included components.

## Base system

| Component | Source | License | Notes |
|---|---|---|---|
| Ubuntu 24.04 LTS (noble) packages | `archive.ubuntu.com/ubuntu` | free software licenses (GPLv2, GPLv3, LGPL, MIT, BSD, etc.) | Base userland; packages installed via `debootstrap`+apt from the official archive |
| Linux kernel (`linux-image-generic`) | Ubuntu kernel (`kernel.ubuntu.com`) | GPLv2 | Supported upstream kernel; not modified |
| `casper` live-boot system | Ubuntu | GPL | Live-session user creation and boot logic |
| GRUB | Ubuntu | GPLv3 | ISO bootloader (BIOS+UEFI hybrid via `grub-mkrescue`) |
| systemd, NetworkManager, sudo, UFW, AppArmor, unattended-upgrades, auditd, pipewire | Ubuntu | GPL/LGPL/BSD | Core services |

## Desktop environment

| Component | License | Notes |
|---|---|---|
| KDE Plasma (`kde-plasma-desktop`, konsole, dolphin, kate, okular, systemsettings, kinfocenter, discover, kcalc, …) | GPLv2+/GPLv3+/LGPL | Primary desktop environment |
| Qt libraries | LGPLv3 / GPL | Via Plasma |
| KDE Breeze theme & icon theme (system defaults) | LGPL/BSD | Base look-and-feel; Valtus adds a color scheme and wallpaper on top |
| Falkon browser, VLC media player, Ark, Spectacle | GPLv2+/LGPL/AGPL | Default applications |

## Fonts

| Component | License |
|---|---|
| Noto fonts (`fonts-noto-core`, `fonts-noto-ui-core`, `fonts-noto-color-emoji`) | SIL Open Font License 1.1 |

## Valtus original content

| Asset | License | Notes |
|---|---|---|
| Build/test scripts, docs, Makefile, smoke tests | MIT (project `LICENSE`) | `scripts/`, `tests/`, `docs/`, `Makefile` |
| Valtus logo, emblem, wallpaper, `ValtusDark.colors` | CC0-1.0 (dedicated public domain) | Original vector assets under `branding/` |

## Trademarks

- "Ubuntu" is a trademark of Canonical Ltd. (https://ubuntu.com/trademarks);
  referenced here only to describe the technical base. Valtus is not
  affiliated with or endorsed by Canonical.
- "KDE", "K Desktop Environment", and the KDE logo are trademarks of the KDE
  e.V.; used descriptively. Valtus is not affiliated with or endorsed by KDE.
- "Valtus" is the project's own name; no upstream trademark is claimed.

## Security-sensitive configuration

`config/valtus.env` contains the fixed, documented live-session credentials.
They are demo credentials for a live ISO whose design intent is local use.
The threat model and rationale are documented in `docs/ARCHITECTURE.md`
(§ Security model) and `docs/INSTALLATION.md`.
