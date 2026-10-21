# Valtus Antivirus — integration plan

Source project: `C:\Users\hp\Desktop\Valtus antivirus\valtus-security`
(version 1.0.0, GPL-3.0-or-later, Python, ClamAV-based). This document
records the review findings and the integration plan; it is updated as the
integration proceeds.

## 1. Reviewed state (2026-10-21)

**Present and well-designed:**
- `src/valtus_security/` package: `scanner/` (clamscan offline backend, daemon
  backend, output parser, enumeration), `services/` (command runner, systemd
  integration), documented architecture (unprivileged front end + narrow
  privileged helper; argv execution only; re-validated paths; nothing deleted
  on a detection alone).
- `pyproject.toml`: setuptools, entry point `valtus-security =
  valtus_security.main:main`, pytest markers (linux / integration / eicar).
- Test scripts: EICAR, instream, real clamav tests, verification helpers.

**Missing (blocks packaging):**
- `src/valtus_security/main.py` — the GUI/CLI entry point (referenced by
  `[project.scripts]`) does not exist.
- `packaging/debian/` (control, rules, install) — referenced by code comments,
  not present.
- `tests/` tree — pytest configured but no tests in the tree.
- `README.md` — referenced by pyproject `readme =`.

## 2. Target platform facts (Valtus = Ubuntu 24.04 noble, verified)

| Requirement | noble status |
|---|---|
| `clamav` | AVAIL 1.0.5+dfsg-1.1ubuntu3 |
| `libclamav11t64` (runtime lib, pulled by clamav) | AVAIL |
| `clamav-daemon` (daemon backend, preferred) | AVAIL |
| `clamav-freshclam` (signature updates) | AVAIL |
| `python3-psutil` | AVAIL 5.9.8-2build2 |
| `python3-polib` (translations) | AVAIL 1.1.1-1 |
| `dh-python`, `pybuild-plugin-pyproject`, `debhelper` | AVAIL (packaging) |
| **`python3-pyside6`** | **MISSING — PySide6 is not in noble** (their notes verify against 26.04, where it exists) |

**Consequence for the GUI**: the front end must target **PyQt6**
(`python3-pyqt6` 6.6.1, already shipped in Valtus for the welcome app) or a
noble-compatible Qt binding. Both are thin Qt6 wrappers; porting widget code
is a mechanical binding swap (PySide6 → PyQt6). This is the one upstream
decision needed from the project owner.

## 3. Integration plan (milestone: Valtus 0.2.0)

1. **Complete the app** (upstream project): `main.py` on PyQt6, polkit policy
   for the privileged helper (`.policy` XML under
   `/usr/share/polkit-1/actions/org.valtus.security.policy`), CLI entry point,
   tests (EICAR-based VM test already exists as a pattern).
2. **Debian packaging** (`packaging/debian/`): `valtus-security` package +
   the distro deps above; build in a clean chroot (not on the host), ship
   `systemd` units (`clamav-daemon` behind a Valtus-named service with
   `freshclam` on a timer, opt-in on-access via `fanotify`), `dpkg`-installed
   into the Valtus rootfs during build stage 3 (same mechanism as the
   welcome app install).
3. **Desktop integration**: `.desktop` entry in the KDE menu + kickoff
   favorites; tray applet for live status; welcome app mention; Dolphin
   context-menu "Scan with Valtus Antivirus" (`servicemenus`).
4. **Security posture** (documented in ARCHITECTURE.md):
   - on-access scanning **off by default** (opt-in), signature updates on
     first boot ask for consent; all actions local, no telemetry, no cloud
   - the privileged helper runs only via polkit, narrow actions only
   - quarantine under `/var/lib/valtus-security/quarantine` with metadata
   - the existing `ufw`/AppArmor posture unchanged
5. **Automated tests** (extend `scripts/test_vm.sh`): EICAR scan positive +
   quarantine round-trip + signature-update failure mode (offline) +
   launch from the KDE menu (sendkey), screenshots.
6. **Docs**: `docs/INSTALLATION.md` section, welcome-screen card,
   THIRD-PARTY-LICENSES entry (clamav GPLv2, PyQt6 GPL/LGPL, the project's
   own GPL-3.0-or-later).

## 4. Open questions for the project owner

1. Confirm the PyQt6 path for the GUI on noble (vs. waiting for a 26.04 base).
2. On-access protection default: opt-in (proposed) or on?
3. Ship ClamAV signatures freshclam-enabled at first boot (network on first
   boot) or require manual update?

## 5. Non-goals (0.2.0)

Cloud reputation lookups, telemetry/accounts, browser extensions, a custom
AV engine (ClamAV is the engine), Windows builds.
