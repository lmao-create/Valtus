#!/bin/bash
set -u
X=/tmp/initrd-x
M=$X/main
echo "=== modprobe dry-run resolution against the initramfs tree ==="
ls "$M/lib/modules" 2>/dev/null
modprobe --dry-run --show-depends -d "$M" -S 6.8.0-147-generic overlay 2>&1 | head -5
echo "=== kernel config: module signing ==="
grep -E 'CONFIG_MODULE_SIG|CONFIG_MODULES=' /root/valtus-build/work/rootfs/boot/config-6.8.0-147-generic 2>/dev/null
echo "=== vermagic of the shipped module vs kernel ==="
KVER=6.8.0-147-generic
modinfo -F vermagic -b /root/valtus-build/work/rootfs -k "$KVER" overlay 2>/dev/null || \
  python3 - "$KVER" <<'PY'
import sys, subprocess
kver = sys.argv[1]
ko = f"/root/valtus-build/work/rootfs/lib/modules/{kver}/kernel/fs/overlayfs/overlay.ko.zst"
out = subprocess.run(["strings", ko], capture_output=True, text=True).stdout
for line in out.splitlines():
    if "6.8.0" in line and ("SMP" in line or "mod_unload" in line):
        print("module vermagic:", line)
PY
echo "=== kernel version string from vmlinuz ==="
file /root/valtus-build/work/rootfs/boot/vmlinuz-6.8.0-147-generic | head -1
echo "=== was /casper/initrd rebuilt AFTER modules were installed? ==="
ls -la --time-style=full-iso /root/valtus-build/work/rootfs/boot/initrd.img-6.8.0-147-generic /root/valtus-build/work/iso/casper/initrd
