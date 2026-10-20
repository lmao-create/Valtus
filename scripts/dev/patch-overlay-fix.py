#!/usr/bin/env python3
"""Patch build.sh to guarantee casper can load the overlay module in the
initramfs:
 1. install an initramfs-tools hook (99-valtus-live) that provides
    /usr/bin/{modprobe,insmod,lsmod,rmmod,depmod} compatibility symlinks
    (kmod 31+ in noble keeps them only under /usr/sbin, and any consumer
    running with PATH=/usr/bin:/bin would fail),
 2. force the essential live filesystems (overlay, squashfs, iso9660,
    virtio drivers...) into the initramfs via /etc/initramfs-tools/modules.d/,
 3. keep the initramfs rebuild in stage 3 (it runs after the hook install).
Idempotent: exits if already applied."""
import sys

path = "/mnt/c/Users/hp/Desktop/Custom OS/scripts/build.sh"
with open(path, encoding="utf-8", newline="") as f:
    src = f.read()

if "99-valtus-live" in src:
    print("already applied")
    sys.exit(0)

anchor = '''    # 8) Security + system configuration inside the chroot'''
new_block = '''    # 7b) Guarantee the live-boot initramfs can load modules and filesystems:
    #     - kmod 31+ (noble) keeps modprobe only under /usr/sbin; casper invokes
    #       `modprobe overlay` unqualified, so provide /usr/bin compat symlinks.
    #     - force critical live filesystem/driver modules into the initramfs.
    log "installing live-boot initramfs hardening (modprobe path + forced modules)"
    mkdir -p "$ROOTFS/etc/initramfs-tools/modules.d"
    install -d "$ROOTFS/usr/share/initramfs-tools/hooks"
    cat > "$ROOTFS/usr/share/initramfs-tools/hooks/99-valtus-live" <<'HOOKEOF'
#!/bin/sh -e
# Valtus: ensure kmod tools are reachable via /usr/bin inside the initramfs and
# force the modules casper needs (overlay/squashfs/cdrom).
PREREQ=""
prereqs() { echo "$PREREQ"; }
case $1 in
prereqs) prereqs; exit 0 ;;
esac
. /usr/share/initramfs-tools/hook-functions

for b in modprobe insmod lsmod rmmod depmod; do
  if [ -e "/usr/sbin/$b" ] && [ ! -e "$DESTDIR/usr/bin/$b" ]; then
    mkdir -p "$DESTDIR/usr/bin"
    ln -s "/usr/sbin/$b" "$DESTDIR/usr/bin/$b" 2>/dev/null || true
  fi
done
HOOKEOF
    chmod 755 "$ROOTFS/usr/share/initramfs-tools/hooks/99-valtus-live"
    printf '%s\\n' overlay squashfs loop iso9660 > "$ROOTFS/etc/initramfs-tools/modules.d/valtus-live-fs"
    for m in crc32c zstd_decompress zstd; do printf '%s\\n' "$m" >> "$ROOTFS/etc/initramfs-tools/modules.d/valtus-live-fs"; done
    chmod 644 "$ROOTFS/etc/initramfs-tools/modules.d/valtus-live-fs"

    # 8) Security + system configuration inside the chroot'''

if src.count(anchor) != 1:
    print(f"anchor problem: {src.count(anchor)}")
    sys.exit(1)
src = src.replace(anchor, new_block)

with open(path, "w", encoding="utf-8", newline="") as f:
    f.write(src)
print("patched build.sh")
