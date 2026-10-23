#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
KVER=6.8.0-147-generic
echo "=== test 1: virtio-gpu-gl ==="
qemu-system-x86_64 -enable-kvm -m 512 -machine q35 -display none \
  -device virtio-gpu-gl -cdrom /dev/null 2>&1 | head -3 &
QP=$!
sleep 3; kill $QP 2>/dev/null; wait $QP 2>/dev/null
echo "rc=$?"
echo "=== test 2: virtio-gpu + opengl renderer ==="
qemu-system-x86_64 -enable-kvm -m 512 -machine q35 -display none \
  -vga virtio -display gtk,gl=on 2>&1 | head -3 &
QP=$!
sleep 3; kill $QP 2>/dev/null; wait $QP 2>/dev/null
echo "rc=$?"
echo "=== qemu version ==="
qemu-system-x86_64 --version | head -1
echo "=== virgl support ==="
qemu-system-x86_64 -device help 2>/dev/null | grep -A2 'virtio-gpu' | head -8
