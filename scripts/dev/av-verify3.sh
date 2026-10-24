#!/bin/bash
# Install clamav/ufw first (dependency order), then the local debs, then
# verify a real scan with signatures.
set -u
T=/root/valtus-av-test
run() { chroot "$T" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }

echo "== remove unconfigured local packages first =="
run dpkg --remove --force-remove-reinstreq valtus-security-helper valtus-security 2>&1 | tail -2
echo "== install engine + firewall from the archive =="
run apt-get -qq update >/dev/null 2>&1
run apt-get install -y -qq clamav clamav-daemon ufw python3-psutil 2>&1 | tail -3
echo "== now install the local debs =="
run dpkg -i "$T/packages"/valtus-security_1.0.0_all.deb 2>&1 | tail -3
run dpkg -i "$T/packages"/valtus-security-helper_1.0.0_all.deb 2>&1 | tail -3
run dpkg --configure -a 2>&1 | tail -3
echo "== dpkg status =="
run dpkg -l valtus-security valtus-security-helper 2>/dev/null | grep '^ii'
echo "== engine present? =="
run bash -c 'command -v clamscan && clamscan --version'
echo "== signatures present? =="
run bash -c 'ls -la /var/lib/clamav/ | head -8'
