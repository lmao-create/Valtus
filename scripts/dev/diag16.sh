#!/bin/bash
set -u
C=/root/valtus-inspect/casper-tree
echo "=== MP_QUIET anywhere in casper ==="
grep -rn "MP_QUIET=" "$C" 2>/dev/null | head -5
grep -rn "MP_QUIET" "$C" 2>/dev/null | grep -v 'modprobe' | head -10
echo "=== check blacklist of overlay in initramfs modprobe.d ==="
grep -rn "blacklist.*overlay\|overlay.*blacklist" /tmp/initrd-x/main/etc/modprobe.d/ /tmp/initrd-x/main/usr/lib/modprobe.d/ 2>/dev/null || echo "overlay NOT blacklisted"
echo "=== how does quiet set MP_QUIET? search initramfs scripts ==="
grep -rn "MP_QUIET" /tmp/initrd-x/main/scripts/ 2>/dev/null | head -5
grep -rn "MP_QUIET" /tmp/initrd-x/main/usr/share/ 2>/dev/null | head -5
