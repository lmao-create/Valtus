#!/bin/bash
set -u
W=/root/valtus-qdiag2
rm -rf "$W"; mkdir -p "$W"
ISO=/root/valtus-build/out/valtus-0.1.0-amd64.iso

if [ ! -f "$ISO" ]; then echo "ISO missing: $ISO"; exit 1; fi

qemu-img create -f qcow2 "$W/disk.qcow2" 64G >/dev/null

echo "=== starting qemu with stderr captured ==="
qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 2048 -machine q35 \
  -cdrom "$ISO" -boot order=d \
  -drive "file=$W/disk.qcow2,format=qcow2,if=virtio,media=disk" \
  -nic user,model=virtio-net-pci \
  -display none -vga virtio \
  -serial "unix:$W/serial.sock,server,nowait" \
  -monitor "unix:$W/monitor.sock,server,nowait" \
  -no-reboot \
  -pidfile "$W/qemu.pid" \
  > "$W/qemu.stdout" 2> "$W/qemu.stderr" &
QPID=$!
echo "qemu background pid: $QPID"

for i in 1 2 3 4 5 6; do
  sleep 5
  echo "--- t+$((i*5))s ---"
  if [ -f "$W/qemu.pid" ]; then echo "pidfile: $(cat "$W/qemu.pid")"; else echo "NO pidfile"; fi
  if kill -0 "$QPID" 2>/dev/null; then echo "qemu ALIVE"; else echo "qemu DEAD"; break; fi
  ls -la "$W" | grep -E 'sock|pid'
done

echo "=== stderr ==="
cat "$W/qemu.stderr"
echo "=== stdout (first 5) ==="
head -5 "$W/qemu.stdout"

# serial test
if [ -S "$W/serial.sock" ]; then
  echo "=== reading serial for 10s ==="
  timeout 10 socat -u "UNIX-CONNECT:$W/serial.sock" - | head -5
fi

kill "$QPID" 2>/dev/null
echo "done"
