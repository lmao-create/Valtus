#!/bin/bash
# Diagnose the post-login black screen: boot, log in on the serial console,
# inspect session/compositor state and journal errors, take a screendump.
set -o nounset -o pipefail

P="/mnt/c/Users/hp/Desktop/Custom OS"
. "$P/config/distro.conf"
. "$P/config/valtus.env"

R=/root/valtus-build/work/rootfs
KVER=6.8.0-147-generic
W=/root/valtus-dbg-s
rm -rf "$W"; mkdir -p "$W/screens"

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

if ! wait_pat "login:" 240; then echo "FAIL: no login prompt"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1; fi
send "valtus"; sleep 3; send "$LIVE_USER_PASSWORD"
if ! wait_pat 'valtus@valtus' 60; then echo "FAIL: login"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1; fi
echo "== logged in on serial; gathering session state =="
send "echo ==SESSIONS==; loginctl --no-legend"
send "echo ==PROCS==; ps aux | grep -E 'kwin|plasmashell|Xorg|sddm' | grep -v grep"
send "echo ==JOURNAL==; journalctl -b --no-pager | grep -iE 'kwin|plasmashell|plasma.session|EGL|gbm|dri' | tail -20"
send "echo ==DISMODES==; ls /dev/dri 2>/dev/null"
send "echo ==GROUPS==; id"
sleep 12

# screenshot of whatever is on screen
printf 'screendump %s/screens/after-login.ppm\n' "$W" > /tmp/m.cmd
socat - "UNIX-CONNECT:$W/mon.sock" < /tmp/m.cmd >/dev/null 2>&1 || true
sleep 15
kill "$QPID" "$SPID" "$KPID" 2>/dev/null
echo "== session state =="
awk '/==SESSIONS==/{f=1} f' "$LOG" | head -45
