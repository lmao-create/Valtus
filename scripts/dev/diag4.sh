#!/bin/bash
set -u
I=/root/valtus-build/work/iso/casper/initrd
R=/root/valtus-build/work/rootfs
echo "=== top-level dirs in initrd ==="
cpio -it < "$I" 2>/dev/null | awk -F/ '{print $1}' | sort | uniq -c | sort -rn | head -12
echo "=== lib/ contents ==="
cpio -it < "$I" 2>/dev/null | grep '^lib/' | head -15
echo "=== any mod* anywhere ==="
cpio -it < "$I" 2>/dev/null | grep -i 'mod' | head -10
echo "=== count of files total ==="
cpio -it < "$I" 2>/dev/null | wc -l
echo "=== busybox/casper present? ==="
cpio -it < "$I" 2>/dev/null | grep -c 'casper'
echo "=== modules tree on rootfs: count ==="
find "$R/lib/modules/6.8.0-147-generic" -name '*.ko*' 2>/dev/null | wc -l
echo "=== initramfs.conf key settings ==="
grep -vE '^#|^$' "$R/etc/initramfs-tools/initramfs.conf" 2>/dev/null
