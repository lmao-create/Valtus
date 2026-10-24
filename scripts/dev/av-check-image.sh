#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
run() { chroot "$R" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }
echo "== dpkg status in the built image =="
run dpkg -l valtus-security valtus-security-helper python3-pyside6-compat 2>&1 | grep -E '^(ii|in|iU|iF)' || echo "NONE INSTALLED"
echo "== files present? =="
ls -la "$R/usr/bin/valtus-security" "$R/usr/libexec/valtus-security-helper" "$R/usr/share/polkit-1/actions/org.valtus.security.policy" 2>&1
echo "== clamav engine in image =="
run dpkg -l clamav | grep '^ii' || echo "clamav MISSING"
