#!/bin/bash
set -u
F=/root/valtus-inspect/casper-tree/usr/share/initramfs-tools/scripts/casper
echo "=== setup_overlay (line 545-600) ==="
sed -n '545,600p' "$F"
echo
echo "=== how MP_QUIET is defined ==="
grep -n "MP_QUIET=" "$F" | head -3
