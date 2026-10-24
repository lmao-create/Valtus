#!/bin/bash
# Clean-room verification: fresh rootfs copy, install deps + the three debs,
# confirm ii state and EICAR detection.
set -u
R=/root/valtus-build/work/rootfs
T=/root/valtus-av-clean
rm -rf "$T"; cp -a "$R" "$T"
mkdir -p "$T/packages"; cp /root/valtus-av-build/repo/*.deb "$T/packages/"
for d in proc sys dev; do [ "$(findmnt -n -o TARGET "$T/$d" 2>/dev/null)" = "$T/$d" ] || mount --bind "/$d" "$T/$d"; done
run() { chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }

echo "== install the three local debs =="
run dpkg -i /packages/valtus-security_1.0.0_all.deb 2>&1 | tail -2
run dpkg -i /packages/valtus-security-helper_1.0.0_all.deb 2>&1 | tail -2
run dpkg -i /packages/python3-pyside6-compat_6.6.1-0valtus1_all.deb 2>&1 | tail -2
run dpkg --configure -a
echo "== ii count (expect 3) =="
run dpkg -l valtus-security valtus-security-helper python3-pyside6-compat | grep -c '^ii'
run dpkg -l valtus-security valtus-security-helper python3-pyside6-compat | grep '^ii'
echo "== app =="
run valtus-security --version
run python3 -c "from PySide6.QtWidgets import QApplication; print('shim OK')"
echo "== EICAR =="
run bash -c 'mkdir -p /root/e2 && printf "X5O!P%%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*" > /root/e2/eicar.txt && valtus-security scan /root/e2 2>&1 | tail -5'
echo "== status =="
run valtus-security status 2>&1 | head -6
for d in proc sys dev; do umount "$T/$d" 2>/dev/null || true; done
echo "clean-room rootfs kept at $T"
