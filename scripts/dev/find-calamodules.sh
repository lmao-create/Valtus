#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "=== calamares packages installed ==="
dpkg --root="$R" -l | grep -i calamares
echo "=== module .so locations ==="
dpkg --root="$R" -L calamares 2>/dev/null | grep -E '\.so' | head -12
echo "=== does libcalamares provide partition/kpmcore module? ==="
dpkg --root="$R" -L calamares 2>/dev/null | grep -iE 'partition|kpmcore|users|bootloader|unpackfs' | head -10
echo "=== total files in calamares package ==="
dpkg --root="$R" -L calamares 2>/dev/null | wc -l
echo "=== any calamares module .so in the whole rootfs? ==="
find "$R" -name '*calamares*' -name '*.so*' 2>/dev/null | head -8
