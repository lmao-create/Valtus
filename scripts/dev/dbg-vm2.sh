#!/bin/bash
# Reproduce the ISO boot verbosely: same as grub.cfg entry 0 but WITHOUT
# `quiet splash` (they suppress every casper message — that is why the
# original failure was silent). If the failure reproduces, the casper error
# output will be visible.
set -o nounset -o pipefail

B=/root/valtus-build
R=$B/work/rootfs
ISO="/mnt/c/Users/hp/Desktop/Custom OS/releases/valtus-0.1.0-amd64.iso"
KVER=6.8.0-147-generic
W=/root/valtus-dbg2
rm -rf "$W"; mkdir -p "$W"

S_SOCK="$W/serial.sock"
LOG="$W/serial.log"
FIFO="$W/cmd.fifo"
: > "$LOG"
mkfifo "$FIFO"
sleep infinity > "$FIFO" &
KPID=$!

qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 2048 -machine q35 \
  -kernel "$R/boot/vmlinuz-$KVER" -initrd "$R/boot/initrd.img-$KVER" \
  -append "boot=casper console=tty0 console=ttyS0,115200n8" \
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

MODE="${1:-boot}"
if [ "$MODE" = "shell" ]; then
  # after casper's panic, an interactive (initramfs) busybox shell is up
  if wait_pat "initramfs\|Spawning shell" 240; then
    echo "PASS: shell reached"
  else
    echo "FAIL: no shell"; tail -25 "$LOG"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1
  fi
  sleep 2
  echo 'echo "PATH=$PATH"; command -v modprobe; modprobe "" -b overlay; echo "EMPTY_ARG_RC=$?"; modprobe -q -b overlay; echo "Q_B_RC=$?"; grep overlay /proc/filesystems || echo NO-OVERLAY; grep -i overlay /lib/modules/$(uname -r)/modules.builtin 2>/dev/null || echo "overlay NOT in modules.builtin"' > "$FIFO"
  sleep 8
  echo 'poweroff -f' > "$FIFO"
  sleep 4
  kill "$QPID" "$SPID" "$KPID" 2>/dev/null
  echo "=== output ==="
  tail -40 "$LOG"
  exit 0
fi

# plain verbose boot: watch until cow failure or success
if wait_pat "cow format specified" 300; then
  echo "RESULT: reproduced the failure (no quiet)"
elif wait_pat "login:" 300; then
  echo "RESULT: booted without quiet?!"
else
  echo "RESULT: timeout"
fi
sleep 3
echo "=== casper output around the failure/success ==="
grep -a -B5 -A10 "cow format specified\|overlay" "$LOG" | tail -50
echo "=== last 20 lines ==="
tail -20 "$LOG"
kill "$QPID" "$SPID" "$KPID" 2>/dev/null
