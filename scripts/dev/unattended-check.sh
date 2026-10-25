#!/bin/bash
set -u
P="/mnt/c/Users/hp/Desktop/Custom OS"
echo "=== settings.conf module references ==="
grep -nA3 'modules-search' "$P/config/installer/settings.conf" | head -8
echo "=== does it reference the unattended module? ==="
grep -c 'unattended' "$P/config/installer/settings.conf"
echo "=== module files to be installed ==="
ls "$P/config/installer/modules/"
echo "=== calamares unattended module ships with the package ==="
ls /root/valtus-build/work/rootfs/usr/lib/calamares/modules/unattended/ 2>/dev/null || echo "(not in image yet)"
find /root/valtus-build/work/rootfs/usr/lib/calamares -name '*unattended*' 2>/dev/null | head -3
