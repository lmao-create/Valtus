#!/bin/bash
# Complete the AV verification: install runtime deps (clamav, ufw) into the
# test rootfs, then run a real scan + status.
set -u
T=/root/valtus-av-test
PKGS=/root/valtus-av-test/packages

run() { chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }

echo "== install runtime deps =="
run apt-get -qq update >/dev/null 2>&1
run apt-get install -y -qq clamav ufw 2>&1 | tail -2
echo "== reconfigure the failing packages =="
run dpkg --configure -a 2>&1 | tail -3
run dpkg -i "$PKGS"/valtus-security_1.0.0_all.deb "$PKGS"/valtus-security-helper_1.0.0_all.deb 2>&1 | tail -4
echo "== dpkg status =="
run dpkg -l valtus-security valtus-security-helper 2>/dev/null | grep '^ii' || true
echo "== EICAR scan test =="
run bash -c '
mkdir -p /root/av-test && cd /root/av-test
printf "%s" "X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*" > eicar.txt
valtus-security scan /root/av-test 2>&1 | tail -12'
echo "== status check =="
run bash -c 'valtus-security status 2>&1 | head -20 || valtus-security --help'
