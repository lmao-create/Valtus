#!/bin/bash
# Diagnose the casper "overlay: no support found" boot failure.
set -u
I=/root/valtus-build/work/iso/casper/initrd
R=/root/valtus-build/work/rootfs

echo "=== initramfs.conf ==="
grep -E '^MODULES|^COMPRESS' "$R/etc/initramfs-tools/initramfs.conf" 2>/dev/null

echo "=== modules.d present in rootfs ==="
ls -la "$R/etc/initramfs-tools/modules.d/" 2>/dev/null || echo "(no modules.d)"

echo "=== overlay in the built initrd ==="
lsinitramfs "$I" 2>/dev/null | grep -i overlay | head -5 || echo "NO overlay module in initrd"

echo "=== overlay module available in the kernel package ==="
ls "$R/lib/modules/6.8.0-147-generic/kernel/fs/overlayfs/" 2>/dev/null || echo "NO overlayfs on disk"

echo "=== quick decompress test ==="
zstd -dc "$I" > /tmp/initrd.cpio 2>/dev/null
ls -la /tmp/initrd.cpio
cpio -it < /tmp/initrd.cpio 2>/dev/null | grep -i 'overlay' | head -5 || echo "cpio: no overlay entries"
echo "=== test: what modules ARE in the initrd (fs/*) ==="
cpio -it < /tmp/initrd.cpio 2>/dev/null | grep 'lib/modules.*kernel/fs/' | head -10
rm -f /tmp/initrd.cpio
