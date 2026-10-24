#!/bin/bash
# Functional test of the built debs: install into a scratch copy of the
# rootfs, then verify the shim, the entry point and the module imports.
set -u
R=/root/valtus-build/work/rootfs
T=/root/valtus-av-test
PKGS=/root/valtus-av-build/repo
rm -rf "$T"; cp -a "$R" "$T"   # full copy (956G volume, fine)
mkdir -p "$T/packages"
cp "$PKGS"/*.deb "$T/packages/"   # after the copy, so they survive

for d in proc sys dev; do [ "$(findmnt -n -o TARGET "$T/$d" 2>/dev/null)" = "$T/$d" ] || mount --bind "/$d" "$T/$d"; done
cp /etc/resolv.conf "$T/etc/resolv.conf"

echo "== install debs into test rootfs =="
chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  bash -c 'apt-get -qq update >/dev/null 2>&1; dpkg -i /packages/*.deb 2>&1 | tail -6' || true

echo "== fix deps (psutil, pyqt6) =="
chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  apt-get install -y -qq python3-psutil 2>&1 | tail -2

echo "== verify: shim import =="
chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  python3 -c "from PySide6.QtCore import Qt; from PySide6.QtWidgets import QApplication; print('PySide6 shim OK:', Qt, QApplication)"

echo "== verify: app imports =="
chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  python3 -c "import valtus_security; from valtus_security import main; print('app import OK', valtus_security.__version__)"

echo "== verify: entry point =="
chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  bash -c 'command -v valtus-security && valtus-security --help 2>&1 | head -8'

echo "== verify: headless scan smoke =="
chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  bash -c 'valtus-security scan --help 2>&1 | head -6'

echo "== verify: dpkg status =="
chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  dpkg -l valtus-security valtus-security-helper python3-pyside6-compat 2>/dev/null | grep '^ii'

for d in proc sys dev; do umount "$T/$d" 2>/dev/null || true; done
echo "TESTROOT=$T (kept for inspection)"
