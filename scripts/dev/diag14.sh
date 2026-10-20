#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
X=/tmp/initrd-x/main
echo "=== modprobe anywhere in the initramfs? ==="
lsinitramfs /root/valtus-build/work/iso/casper/initrd 2>/dev/null | grep -i modprobe || echo "NOWHERE"
echo "=== initramfs-tools hooks in the chroot ==="
ls "$R/usr/share/initramfs-tools/hooks/" 2>/dev/null
echo "=== kmod hook content (first 40 lines) ==="
head -40 "$R/usr/share/initramfs-tools/hooks/kmod" 2>/dev/null || echo "NO kmod hook"
echo "=== modprobe in rootfs? ==="
ls -la "$R/usr/bin/modprobe" 2>/dev/null || echo "no modprobe in rootfs"
dpkg --root="$R" -l kmod 2>/dev/null | tail -2
