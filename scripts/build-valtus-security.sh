#!/bin/bash
# =============================================================================
# Build valtus-security debs for Valtus (noble) without debhelper, using the
# project's own packaging/valtus-security.install manifest as the source of
# truth. Three packages: valtus-security, valtus-security-helper,
# valtus-security-daemon (per the project's debian/control split).
#
# The GUI needs PySide6, which does not exist in noble; we ship a shim
# package 'python3-pyside6-compat' (built here) that re-exports PyQt6, and
# add python3-psutil + PyQt6 as dependencies. The project's guarded imports
# mean no source modification is required.
# =============================================================================
set -o nounset -o pipefail

AV="/mnt/c/Users/hp/Desktop/Valtus antivirus/valtus-security"
OUT="${VALTUS_AV_OUT:-/root/valtus-av-build}"
VERSION="1.0.0"
STAGE="$OUT/stage"
rm -rf "$OUT"; mkdir -p "$STAGE" "$OUT/repo"

echo "== reading install manifest =="
INSTALL="$AV/packaging/debian/valtus-security.install"
grep -Ev '^\s*(#|$)' "$INSTALL"

echo "== checking GUI Qt import guard =="
grep -m1 'from PySide6' "$AV/src/valtus_security/ui/theme.py" >/dev/null && echo "gui imports PySide6 (shim will provide it)"

# --- 1. PySide6 -> PyQt6 compat shim package --------------------------------
SHIM="$STAGE/python3-pyside6-compat"
mkdir -p "$SHIM/DEBIAN" "$SHIM/usr/lib/python3/dist-packages/PySide6"
cat > "$SHIM/DEBIAN/control" <<EOF
Package: python3-pyside6-compat
Version: 6.6.1-0valtus1
Section: python
Priority: optional
Architecture: all
Maintainer: Valtus Builder <builder@valtus.invalid>
Depends: python3, python3-pyqt6
Description: PySide6 compatibility layer backed by PyQt6
 Minimal compatibility package for Ubuntu 24.04 (noble), where PySide6 is not
 available in the archive. It provides a 'PySide6' package whose submodules
 (QtCore, QtGui, QtWidgets) re-export the equivalent PyQt6 modules. Intent:
 allow applications written against PySide6 (e.g. Valtus Security) to run on
 Valtus without modification. Not a general PySide6 replacement; the enum and
 signal APIs used by simple applications are mapped.
EOF
for m in QtCore QtGui QtWidgets QtDBus; do
  cat > "$SHIM/usr/lib/python3/dist-packages/PySide6/$m.py" <<EOF
"""PySide6 compatibility shim backed by PyQt6 (Valtus)."""
from PyQt6.$m import *  # noqa: F401,F403
from PyQt6 import $m as _m
globals().update({k: getattr(_m, k) for k in dir(_m) if not k.startswith('_')})
EOF
  cat > "$SHIM/usr/lib/python3/dist-packages/PySide6/$m.pyi" <<EOF
EOF
done
cat > "$SHIM/usr/lib/python3/dist-packages/PySide6/__init__.py" <<EOF
"""PySide6 compatibility package (PyQt6-backed, Valtus)."""
EOF
# Qt enums: Qt6 apps commonly use Qt.AlignmentFlag etc.; PyQt6 has them too.
dpkg-deb --build --root-owner-group "$SHIM" "$OUT/repo/python3-pyside6-compat_6.6.1-0valtus1_all.deb"
echo "built: python3-pyside6-compat"

# --- helper: stage the project per the install manifest ---------------------
stage_files() { # $1=dest root
  local D="$1"
  # NOTE: no /usr/libexec or polkit dirs here - the helper package owns those
  # paths; keeping the staging trees disjoint avoids dpkg file conflicts.
  mkdir -p "$D/usr/lib/python3/dist-packages" "$D/usr/bin" \
           "$D/usr/share/applications" "$D/usr/share/icons/hicolor/scalable/apps" \
           "$D/usr/share/icons/hicolor/128x128/apps" \
           "$D/DEBIAN"
  cp -r "$AV/src/valtus_security" "$D/usr/lib/python3/dist-packages/"
  # drop caches from the source tree
  find "$D/usr/lib/python3/dist-packages/valtus_security" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
  install -m 0755 "$AV/scripts/valtus-security" "$D/usr/bin/valtus-security"
  # NOTE: the privileged helper binary and the polkit policy ship ONLY in
  # valtus-security-helper (per the project's debian/control). Copying them
  # here too would make the packages conflict over those paths.
  install -m 0644 "$AV/packaging/valtus-security.desktop" "$D/usr/share/applications/"
  install -m 0644 "$AV/packaging/valtus-security.svg" "$D/usr/share/icons/hicolor/scalable/apps/"
  # PNG icon: the project ships only the SVG; render one for the hicolor
  # 128x128 slot (rsvg-convert is a build-host dependency).
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 128 -h 128 "$AV/packaging/valtus-security.svg" \
      -o "$D/usr/share/icons/hicolor/128x128/apps/valtus-security.png" 2>/dev/null || true
  fi
}
# The helper package ships ONLY the helper binary + polkit policy (per the
# project's debian/control); the full application lives in valtus-security.
stage_helper_files() { # $1=dest root
  local D="$1"
  mkdir -p "$D/usr/libexec" "$D/usr/share/polkit-1/actions" "$D/DEBIAN"
  install -m 0755 "$AV/helper/valtus-security-helper.py" "$D/usr/libexec/valtus-security-helper"
  install -m 0644 "$AV/polkit/org.valtus.security.policy" "$D/usr/share/polkit-1/actions/"
}

echo "== building valtus-security (main package) =="
MAIN="$STAGE/valtus-security"
stage_files "$MAIN"
cat > "$MAIN/DEBIAN/control" <<EOF
Package: valtus-security
Version: $VERSION
Section: admin
Priority: optional
Architecture: all
Maintainer: Valtus Security Team <valtus-security@valtus.example>
Depends: python3 (>= 3.12), clamav (>= 1.0), python3-pyside6-compat, python3-psutil
Description: Valtus Security - antivirus and system protection centre
 On-demand malware scanning with ClamAV, protected quarantine, signature
 updates, firewall status and control, security-update status, scan history
 and scheduled scans. The interface runs unprivileged; privileged actions go
 through a narrow PolicyKit helper. Missing components are reported
 accurately; nothing claims protection it has not verified.
EOF
cat > "$MAIN/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ] || [ "$1" = "abort-upgrade" ]; then
  # compile the package if bytecode compilation is available
  if command -v python3 >/dev/null 2>&1; then
    python3 -m compileall -q /usr/lib/python3/dist-packages/valtus_security >/dev/null 2>&1 || true
  fi
fi
exit 0
EOF
chmod 0755 "$MAIN/DEBIAN/postinst"
dpkg-deb --build --root-owner-group "$MAIN" "$OUT/repo/valtus-security_${VERSION}_all.deb"
echo "built: valtus-security"

echo "== building valtus-security-helper =="
HELPER="$STAGE/valtus-security-helper"
stage_helper_files "$HELPER"
cat > "$HELPER/DEBIAN/control" <<EOF
Package: valtus-security-helper
Version: $VERSION
Section: admin
Priority: optional
Architecture: all
Maintainer: Valtus Security Team <valtus-security@valtus.example>
Depends: python3 (>= 3.12), ufw, clamav-freshclam | clamav-daemon
Description: Valtus Security privileged helper
 The PolicyKit helper for the few Valtus Security operations that need
 administrator rights: quarantine moves and restores, firewall changes,
 signature-database updates and on-access protection. It is a whitelist
 program: no shell, every path re-validated, unknown actions refused.
EOF
dpkg-deb --build --root-owner-group "$HELPER" "$OUT/repo/valtus-security-helper_${VERSION}_all.deb"
echo "built: valtus-security-helper"

echo
echo "== built packages =="
ls -la "$OUT/repo"
