#!/bin/bash
set -u
C=/root/valtus-build/work/rootfs/boot/config-6.8.0-147-generic
echo "=== MODULE_DECOMPRESS / compression ==="
grep -E 'DECOMPRESS|MODULE_COMPRESS|CONFIG_ZSTD' "$C" | head -8
echo "=== early/early2 contents (first entries) ==="
ls /tmp/initrd-x/early 2>/dev/null | head -6
ls /tmp/initrd-x/early2 2>/dev/null | head -6
echo "=== sizes ==="
du -sh /tmp/initrd-x/early /tmp/initrd-x/early2 /tmp/initrd-x/main 2>/dev/null
echo "=== main/lib symlink or dir? ==="
ls -la /tmp/initrd-x/main/ | grep -E 'lib|usr'
echo "=== is main/usr/lib/modules/... complete? count ==="
find /tmp/initrd-x/main/usr/lib/modules -name '*.ko*' | wc -l
