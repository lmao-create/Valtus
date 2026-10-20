#!/bin/bash
set -u
I=/root/valtus-build/work/iso/casper/initrd
R=/root/valtus-build/work/rootfs
echo "=== overlay entries in initrd (plain cpio) ==="
cpio -it < "$I" 2>/dev/null | grep -i overlay || echo "NO OVERLAY IN INITRD"
echo "=== fs modules sample in initrd ==="
cpio -it < "$I" 2>/dev/null | grep 'kernel/fs/' | head -10
echo "=== module count ==="
cpio -it < "$I" 2>/dev/null | grep -c 'lib/modules.*\.ko'
echo "=== zstd in the chroot? ==="
ls -la "$R/usr/bin/zstd" 2>/dev/null || echo "no zstd binary in rootfs"
dpkg --root="$R" -l zstd 2>/dev/null | tail -2 || echo "zstd package not recorded"
echo "=== mkinitramfs compressor note ==="
grep -rn 'COMPRESS' "$R/etc/initramfs-tools/initramfs.conf" "$R/etc/initramfs-tools/update-initramfs.conf" 2>/dev/null
