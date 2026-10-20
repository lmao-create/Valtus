#!/bin/bash
set -u
X=/tmp/initrd-x/main
echo "=== modprobe.d / kmod config in initramfs ==="
find "$X/etc/modprobe.d" "$X/usr/lib/modprobe.d" "$X/lib/modprobe.d" -type f 2>/dev/null | head -10
echo "=== blacklists? ==="
grep -rn blacklist "$X/etc/modprobe.d" "$X/usr/lib/modprobe.d" "$X/lib/modprobe.d" 2>/dev/null | head -5 || echo "(no modprobe.d dirs in initramfs)"
echo "=== kmod binaries in initramfs ==="
ls -la "$X/usr/bin/modprobe" "$X/bin/modprobe" 2>/dev/null
echo "=== initramfs-tools hooks that could interfere (valtus) ==="
ls "$X/scripts/" 2>/dev/null | head -20
echo "=== does initramfs /scripts/casper call modprobe -b? ==="
grep -n 'modprobe.*-b\|modprobe.*overlay' "$X/scripts/casper" 2>/dev/null | head -5
