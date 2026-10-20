#!/bin/bash
# Debug the casper overlay failure: direct-kernel-boot the shipped kernel+initrd
# with break=premount, then run diagnostics in the initramfs shell.
# Robust serial I/O: ONE bidirectional socat client via a FIFO (a second
# client connecting to the socket would drop the reader).
set -o nounset -o pipefail

B=/root/valtus-build
R=$B/work/rootfs
ISO="/mnt/c/Users/hp/Desktop/Custom OS/releases/valtus-0.1.0-amd64.iso"
KVER=6.8.0-147-generic
W=/root/valtus-dbg
rm -rf "$W"; mkdir -p "$W"

S_SOCK="$W/serial.sock"
LOG="$W/serial.log"
FIFO="$W/cmd.fifo"
: > "$LOG"
mkfifo "$FIFO"
# keep the FIFO open so socat never sees EOF
sleep infinity > "$FIFO" &
KPID=$!

qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 2048 -machine q35 \
  -kernel "$R/boot/vmlinuz-$KVER" -initrd "$R/boot/initrd.img-$KVER" \
  -append "boot=casper console=ttyS0,115200n8 break=premount" \
  -cdrom "$ISO" -boot order=d \
  -nic user,model=virtio-net-pci \
  -display none -vga virtio \
  -serial "unix:$S_SOCK,server,nowait" \
  -no-reboot -pidfile "$W/qemu.pid" &
QPID=$!
sleep 2
echo "qemu pid $(cat "$W/qemu.pid" 2>/dev/null)"

socat - "UNIX-CONNECT:$S_SOCK" < "$FIFO" >> "$LOG" 2>/dev/null &
SPID=$!

send() { echo "$1" > "$FIFO"; sleep 1; }
wait_pat() {
  local pattern="$1"
  local secs="$2"
  local deadline=$((SECONDS+secs))
  while [ $SECONDS -lt $deadline ]; do
    grep -q "$pattern" "$LOG" 2>/dev/null && return 0
    sleep 2
  done
  return 1
}

if wait_pat "Spawning shell within the initramfs\|Break requested" 180; then
  echo "PASS: reached premount break shell"
else
  echo "FAIL: no break shell; log tail:"
  tail -20 "$LOG"
  kill "$QPID" "$SPID" "$KPID" 2>/dev/null
  exit 1
fi
sleep 3

echo "=== diagnostics in the initramfs ==="
send "uname -r"
send "echo PATH=\$PATH"
send "command -v modprobe || echo MODPROBE-NOT-IN-PATH"
send "ls /lib/modules/\$(uname -r)/kernel/fs/overlayfs/ || echo NO-OVERLAY-DIR"
send "grep overlay /proc/filesystems || echo NOT-IN-PROC-FS"
send "/usr/sbin/modprobe overlay; echo MODPROBE_RC=\$?"
send "modprobe overlay; echo MODPROBE2_RC=\$?"
send "grep overlay /proc/filesystems || echo STILL-NOT-IN-PROC"
send "dmesg | tail -15"
sleep 10
echo "poweroff" > "$FIFO"
sleep 5
kill "$QPID" "$SPID" "$KPID" 2>/dev/null

echo
echo "=== captured diagnostics ==="
grep -a -E "MODPROBE|PATH=|overlay|modprobe|invalid|disagrees|NO-OVERLAY|NOT-IN-PROC" "$LOG" | tail -30
