#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
run() { chroot "$R" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }
echo "== clamav-daemon state =="
run dpkg -l clamav-daemon 2>&1 | grep -E '^(ii|iU|iF|in)' || echo "not installed"
echo "== clamav-freshclam available? =="
run dpkg -l clamav-freshclam 2>&1 | grep -E '^(ii|iU|iF|in)' || echo "not installed"
echo "== helper configure attempt (verbose) =="
run dpkg --configure valtus-security-helper 2>&1 | tail -5
