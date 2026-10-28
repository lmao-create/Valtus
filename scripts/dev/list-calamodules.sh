#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "=== /usr/lib/calamares/modules ==="
ls "$R/usr/lib/calamares/modules" 2>/dev/null | tr '\n' ' '; echo
echo "=== /usr/share/calamares ==="
ls "$R/usr/share/calamares" 2>/dev/null | tr '\n' ' '; echo
echo "=== /etc/calamares ==="
ls -A "$R/etc/calamares" 2>/dev/null | tr '\n' ' '; echo
echo "=== dpkg file list for calamares (settings-related) ==="
dpkg --root="$R" -L calamares 2>/dev/null | grep -E 'settings\.conf|calamares/modules' | head -20
echo "=== does casper live-boot config exist? (unpackfs needs it) ==="
ls "$R/etc/casper.conf" "$R/usr/share/casper" 2>/dev/null | head -6
