# Valtus Antivirus — integration (IMPLEMENTED)

Source project: `C:\Users\hp\Desktop\Valtus antivirus\valtus-security`
(version 1.0.0, GPL-3.0-or-later, Python, ClamAV-based). **Status: built,
installed into the image, and functionally verified.**

## 1. What was verified (2026-10-24)

Verified in a scratch copy of the Valtus rootfs:

| Check | Result |
|---|---|
| `python3-pyside6-compat` shim (PySide6 → PyQt6) | PASS — `from PySide6.QtWidgets import QApplication` works |
| `valtus_security` package import | PASS — version 1.0.0 |
| `/usr/bin/valtus-security` entry point | PASS — `--help`, `--version` |
| dpkg install (3 packages: app, helper, shim) | PASS — all `ii` |
| `freshclam` signature update | PASS — 3,642,895 signatures (108 MB DB) |
| **EICAR detection** | PASS — `Detections: 1, /root/eicar/eicar.txt: Eicar-Test-Signature` |
| Status honest reporting | PASS — reports engine/signatures/real-time/firewall accurately |

## 2. Packaging approach

The project ships Debian-control metadata but the Valtus build host has no
debhelper/dh-python, so `scripts/build-valtus-security.sh` builds the debs
directly with `dpkg-deb --build`, driven by the project's own
`packaging/debian/valtus-security.install` manifest:

| Package | Contents |
|---|---|
| `valtus-security` | app (`/usr/lib/python3/dist-packages/valtus_security`), `/usr/bin/valtus-security`, polkit policy, `.desktop` + icon |
| `valtus-security-helper` | `/usr/libexec/valtus-security-helper` + polkit policy only (no shared files with the app) |
| `python3-pyside6-compat` | **Valtus-built** PySide6→PyQt6 shim (PySide6 is not in noble) |

## 3. noble adaptation (the one upstream decision)

The upstream `control` lists `python3-pyside6.*` (verified against 26.04, where
those exist). **noble has no PySide6**, so the Valtus build ships the shim
package instead and adds `python3-pyqt6` (already in the image for the
welcome app) + `python3-psutil` as dependencies. No upstream source file was
modified — the project's optional/stubbed Qt imports make the shim
sufficient for the modules it uses (QtCore/QtGui/QtWidgets + enums).

If upstream later targets noble directly, replace the shim with
`python3-pyside6.qtcore`/`.qtwidgets` from the archive.

## 4. In the image (build stage 3)

- Packages installed: `clamav`, `clamav-daemon`, `python3-psutil` (+ existing
  `python3-pyqt6`), and the three locally-built debs.
- Desktop: `.desktop` entry in the KDE menu (Antivirus category), icon
  installed, and the welcome app mentions it.
- Defaults: **on-access (real-time) protection OFF by default**, scheduled
  scan available via the daemon package (installed; the timer unit is not
  enabled by default — the user opts in from the GUI). Signatures are not
  pre-downloaded (108 MB); the first run offers an update, which needs
  consent. No telemetry, no cloud lookups.

## 5. Security posture

- GUI runs unprivileged; privileged actions go through the polkit helper
  (whitelist program; no shell; paths re-validated) — unchanged upstream
  design.
- The helper package contains no shared files with the app (no dpkg
  file conflicts).
- Quarantine at `/var/lib/valtus-security/quarantine` with metadata;
  nothing is deleted automatically on a detection alone.
- ClamAV database handling unchanged (GPL-2.0, upstream).

## 6. Known limitations

- The PySide6 shim maps `QtCore/QtGui/QtWidgets`; exotic PySide6-only APIs
  (shiboken6 enums with unusual names, QML) are not covered. The app's
  actual usage is covered and verified.
- `python3-pyside6-compat` is a Valtus-built package, not in any archive.
- Scheduled-scan/on-access systemd units are delivered by the helper
  package's upstream layout but are not auto-enabled in 0.1.0 (opt-in).
- First signature download is ~108 MB and needs network + consent.
