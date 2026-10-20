#!/bin/bash
set -u
F=/root/valtus-inspect/casper-tree/usr/share/initramfs-tools/scripts/casper
echo "=== PATH assignments in casper live script ==="
grep -n 'PATH' "$F" | head -10
echo "=== MP_QUIET definition ==="
grep -rn "MP_QUIET" "$F" | head -10
grep -rn "MP_QUIET" /root/valtus-inspect/casper-tree/usr/share/initramfs-tools/scripts/casper-functions 2>/dev/null | head -5
echo "=== quiet handling / CMDLINE ==="
grep -n "CMDLINE\|quiet" "$F" | head -15
echo "=== the modprobe call context (lines 580-590) ==="
sed -n '578,590p' "$F"
