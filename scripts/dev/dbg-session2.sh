#!/bin/bash
# Diagnose the black autologin session: boot with the test-autologin flag,
# log in on the serial console, dump session + compositor state.
set -o nounset -o pipefail

P="/mnt/c/Users/hp/Desktop/Custom OS"
. "$P/config/distro.conf"
. "$P/config/valtus.env"

R=/root/valtus-build/work/rootfs
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
  -append "boot=casper console=tty0 console=ttyS0,115200n8 valtus.test_autologin=1" \
  -cdrom "$P/releases/${DISTRO_ID}-${DISTRO_VERSION}-${DISTRO_ARCH}.iso" -boot order=d \
  -nic user,model=virtio-net-pci \
  -display none -vga virtio \
  -serial "unix:$S_SOCK,server,nowait" \
  -no-reboot -pidfile "$W/qemu.pid" &
QPID=$!
sleep 2

socat - "UNIX-CONNECT:$S_SOCK" < "$FIFO" >> "$LOG" 2>/dev/null &
SPID=$!

send() { echo "$1" > "$FIFO"; sleep 2; }
wait_pat() {
  local pattern="$1"; local secs="$2"; local deadline=$((SECONDS+secs))
  while [ $SECONDS -lt $deadline ]; do
    grep -q "$pattern" "$LOG" 2>/dev/null && return 0
    sleep 3
  done
  return 1
}

wait_pat "login:" 300
send "valtus"; sleep 3; send "$LIVE_USER_PASSWORD"
if ! wait_pat 'valtus@valtus' 60; then echo "FAIL: login"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1; fi
echo "== logged in; dumping state =="
send "echo ==ENVFILE==; cat /home/valtus/.config/plasma-workspace/env/99-valtus-test-gl.sh 2>/dev/null || echo MISSING"
send "echo ==CMDGL==; ls -la /home/valtus/.config/plasma-workspace/env/ 2>/dev/null"
send "echo ==SESSION==; loginctl --no-legend"
send "echo ==PROCS==; ps aux | grep -E 'kwin|plasmashell|startplasma|Xorg' | grep -v grep | head -10"
send "echo ==JWARN==; journalctl -b --no-pager | grep -iE 'kwin|plasmashell|startplasma|EGL|llvmpipe|dri3|gbm|MESA' | tail -25"
sleep 18
kill "$QPID" "$SPID" "$KPID" 2>/dev/null
echo "== captured =="
awk '/==ENVFILE==/{f=1} f' "$LOG" | head -60
