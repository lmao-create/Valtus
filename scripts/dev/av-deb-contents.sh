#!/bin/bash
set -u
echo "=== valtus-security deb contents ==="
dpkg-deb -c /root/valtus-build/av/repo/valtus-security_1.0.0_all.deb
echo
echo "=== valtus-security-helper deb contents ==="
dpkg-deb -c /root/valtus-build/av/repo/valtus-security-helper_1.0.0_all.deb
