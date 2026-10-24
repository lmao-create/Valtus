#!/bin/bash
set -u
T=/root/valtus-av-test
run() { chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }
echo "== purge old, install fixed debs =="
run dpkg --purge valtus-security valtus-security-helper 2>&1 | tail -1
cp /root/valtus-build/av/repo/*.deb "$T/packages/"
run dpkg -i /packages/valtus-security_1.0.0_all.deb
run dpkg -i /packages/valtus-security-helper_1.0.0_all.deb
run dpkg -i /packages/python3-pyside6-compat_6.6.1-0valtus1_all.deb
run dpkg --configure -a
echo "== all three ii? =="
run dpkg -l valtus-security valtus-security-helper python3-pyside6-compat
echo "== app still works =="
run valtus-security --version
run python3 -c "from PySide6.QtWidgets import QApplication; print('shim OK')"
echo "== EICAR again =="
run bash -c 'valtus-security scan /root/eicar 2>&1 | tail -5'
