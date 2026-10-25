#!/bin/bash
set -u
W=/root/valtus-qdiag
rm -rf "$W"; mkdir -p "$W"
ISO=/root/valtus-build/out/valtus-0.1.0-amd64.iso
echo "=== qemu version / kvm ==="
qemu-system-x86_64 --version | head -1
ls -la /dev/kvm 2>&1
echo "=== try starting qemu in the foreground briefly ==="
timeout 12 qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 2048 -machine q35 \
  -cdrom "$ISO" -boot order=d \
  -nic user,model=virtio-net-pci \
  -display none -vga virtio \
  -serial "unix:$W/serial.sock,server,nowait" \
  -monitor "unix:$W/monitor.sock,server,nowait" \
  -no-reboot \
  2>&1 | head -10
echo "rc=$?"
echo "=== files after ==="
ls -la "$W"
