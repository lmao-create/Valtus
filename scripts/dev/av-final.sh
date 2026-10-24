#!/bin/bash
set -u
T=/root/valtus-av-test
run() { chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }

echo "== install local debs =="
run dpkg -i /packages/valtus-security_1.0.0_all.deb
run dpkg -i /packages/valtus-security-helper_1.0.0_all.deb
run dpkg -i /packages/python3-pyside6-compat_6.6.1-0valtus1_all.deb
echo "== configure all =="
run dpkg --configure -a
echo "== dpkg status =="
run dpkg -l valtus-security valtus-security-helper python3-pyside6-compat
echo "== app smoke =="
run valtus-security --version
run python3 -c "from PySide6.QtWidgets import QApplication; print('shim OK')"
echo "== EICAR detection test (real clamscan) =="
run bash -c 'mkdir -p /root/eicar && cd /root/eicar && printf "X5O!P%%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*" > eicar.txt && valtus-security scan /root/eicar 2>&1 | tail -10'
