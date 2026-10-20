#!/bin/bash
set -u
I=/root/valtus-build/work/iso/casper/initrd
R=/root/valtus-build/work/rootfs
echo "=== file type ==="
file "$I"
xxd "$I" | head -2
echo "=== sizes ==="
ls -la "$I" "$R/boot/"
echo "=== try zstd decompress verbosely ==="
zstd -dc "$I" > /tmp/initrd.cpio 2>/tmp/zstd.err; echo "zstd rc=$?"
cat /tmp/zstd.err | head -3
ls -la /tmp/initrd.cpio
echo "=== cpio list (fs overlayfs) ==="
cpio -it < /tmp/initrd.cpio 2>/dev/null | grep -ci overlay
cpio -it < /tmp/initrd.cpio 2>/dev/null | grep 'kernel/fs/' | head -8
rm -f /tmp/initrd.cpio /tmp/zstd.err
echo "=== does the rootfs /boot initrd match? ==="
file "$R/boot/initrd.img-6.8.0-147-generic"
cmp "$R/boot/initrd.img-6.8.0-147-generic" "$I" && echo "SAME" || echo "DIFFERENT (iso copy may be stale)"
echo "=== lsinitramfs exists? ==="
command -v lsinitramfs || echo "lsinitramfs NOT installed on build host"
