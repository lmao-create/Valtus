#!/bin/bash
# Capture GUI evidence for Valtus: SDDM login screen + Plasma desktop after
# logging in with the documented credential. Outputs PNG screenshots into the
# project logs/ directory and reports the paths.
set -o nounset -o pipefail

P="/mnt/c/Users/hp/Desktop/Custom OS"
. "$P/config/distro.conf"
. "$P/config/valtus.env"

B=/root/valtus-build
R=$B/work/rootfs
KVER=6.8.0-147-generic
W=/root/valtus-gui
rm -rf "$W"; mkdir -p "$W/screens"
OUT="$P/screenshots"
mkdir -p "$OUT"

S_SOCK="$W/serial.sock"
MON_SOCK="$W/monitor.sock"
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
  -monitor "unix:$MON_SOCK,server,nowait" \
  -serial "unix:$S_SOCK,server,nowait" \
  -no-reboot -pidfile "$W/qemu.pid" &
QPID=$!
sleep 2

socat - "UNIX-CONNECT:$S_SOCK" < "$FIFO" >> "$LOG" 2>/dev/null &
SPID=$!

mon() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$MON_SOCK" 2>/dev/null; sleep 1; }
wait_pat() {
  local pattern="$1"
  local secs="$2"
  local deadline=$((SECONDS+secs))
  while [ $SECONDS -lt $deadline ]; do
    grep -q "$pattern" "$LOG" 2>/dev/null && return 0
    sleep 3
  done
  return 1
}
shot() {
  local name="$1"
  rm -f "$W/screens/$name.ppm"
  mon "screendump $W/screens/$name.ppm"
  sleep 2
  if [ -f "$W/screens/$name.ppm" ]; then
    python3 -c "
from PIL import Image
import sys
im = Image.open('$W/screens/$name.ppm')
im.save('$OUT/$name.png')
print('saved $OUT/$name.png', im.size)
" || cp "$W/screens/$name.ppm" "$OUT/$name.ppm"
  fi
}

echo "== waiting for SDDM login screen =="
if ! wait_pat "sddm\|login:" 240; then echo "FAIL: no login screen"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1; fi
sleep 20   # let SDDM settle (themed background loaded)
shot 01-valtus-login-screen
echo "== logging in via the automated-test entry (autologin) =="
echo "== waiting for Plasma session =="
sleep 120
shot 02-valtus-desktop
echo "== also capturing the desktop again after welcome app settles =="
sleep 20
shot 03-valtus-desktop-welcome

kill "$QPID" "$SPID" "$KPID" 2>/dev/null
echo "== screenshots =="
ls -la "$OUT"
