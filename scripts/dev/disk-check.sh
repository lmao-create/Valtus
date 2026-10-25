#!/bin/bash
set -u
D=/root/valtus-inst-test/disk.qcow2
echo "=== disk info ==="
qemu-img info "$D" 2>/dev/null | head -6
echo "=== markers in the raw disk ==="
strings -a "$D" 2>/dev/null | grep -aiE 'valtus|grub|ext4|uuid' | head -10 || echo "(no markers)"
echo "=== is the disk mostly empty? ==="
du --apparent-size -h "$D" | cut -f1
