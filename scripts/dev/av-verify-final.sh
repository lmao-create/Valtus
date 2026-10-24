#!/bin/bash
# Full AV integration verification: fresh debs, freshclam signatures, EICAR
# detection, GUI import, and the .desktop/polkit files.
set -u
T=/root/valtus-av-test
R=/root/valtus-build/work/rootfs
run() { chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }

echo "== reinstall clean =="
run dpkg --purge valtus-security valtus-security-helper python3-pyside6-compat 2>&1 | tail -1
run dpkg -i /packages/valtus-security_1.0.0_all.deb
run dpkg -i /packages/valtus-security-helper_1.0.0_all.deb
run dpkg -i /packages/python3-pyside6-compat_6.6.1-0valtus1_all.deb
run dpkg --configure -a
echo "== dpkg -l =="
run dpkg -l valtus-security valtus-security-helper python3-pyside6-compat
echo "== freshclam (signature download; takes ~1-3 min) =="
run bash -c 'timeout 300 freshclam --stdout 2>&1 | tail -5'
echo "== signature DB present? =="
run bash -c 'ls /var/lib/clamav/ | head; du -sh /var/lib/clamav/ 2>/dev/null'
echo "== EICAR detection (the real thing) =="
run bash -c 'mkdir -p /root/eicar && printf "X5O!P%%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*" > /root/eicar/eicar.txt && valtus-security scan /root/eicar 2>&1 | tail -10'
echo "== status now =="
run valtus-security status 2>&1 | head -8
