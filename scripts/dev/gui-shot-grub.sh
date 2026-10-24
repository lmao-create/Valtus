#!/bin/bash
# GUI screenshot via the ISO's own GRUB (real boot path), test-autologin
# entry (GRUB menu entry 3). Robust serial setup: reader starts AFTER qemu.
set -o nounset -o pipefail

P="/mnt/c/Users/hp/Desktop/Custom OS"
. "$P/config/distro.conf"
. "$P/config/valtus.env"

W=/root/valtus-gshot
rm -rf "$W"; mkdir -p "$W/screens"
OUT="$P/screenshots"
mkdir -p "$OUT"

FIFO="$W/cmd.fifo"
mkfifo "$FIFO"
sleep infinity > "$FIFO" &
KPID=$!

qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m 2048 -machine q35 \
  -cdrom "$P/releases/${DISTRO_ID}-${DISTRO_VERSION}-${DISTRO_ARCH}.iso" -boot order=d \
  -nic user,model=virtio-net-pci \
  -display none -vga virtio \
  -serial "unix:$W/serial.sock,server,nowait" \
  -monitor "unix:$W/mon.sock,server,nowait" \
  -no-reboot -pidfile "$W/qemu.pid" &
QPID=$!
sleep 3
[ -f "$W/qemu.pid" ] || { echo "FAIL: qemu did not start"; kill $KPID; exit 1; }
kill -0 "$(cat "$W/qemu.pid")" 2>/dev/null || { echo "FAIL: qemu died at startup"; kill $KPID; exit 1; }
echo "qemu up: $(cat "$W/qemu.pid")"

socat - "UNIX-CONNECT:$W/serial.sock" < "$FIFO" >> "$W/serial.log" 2>/dev/null &
SPID=$!

wait_pat() {
  local pattern="$1"; local secs="$2"; local deadline=$((SECONDS+secs))
  while [ $SECONDS -lt $deadline ]; do
    grep -q "$pattern" "$W/serial.log" 2>/dev/null && return 0
    sleep 2
  done
  return 1
}
mon() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$W/mon.sock" >/dev/null 2>&1; sleep 2; }
shot() {
  local name="$1"
  rm -f "$W/screens/$name.ppm"
  mon "screendump $W/screens/$name.ppm"
  [ -f "$W/screens/$name.ppm" ] && python3 -c "
from PIL import Image
im = Image.open('$W/screens/$name.ppm'); im.save('$OUT/$name.png')
print('saved $OUT/$name.png')"
}

# wait for the GRUB menu on serial, then select entry 3 (automated test)
if wait_pat "automated test\|Valtus" 120; then
  sleep 8
  mon "sendkey down"; mon "sendkey down"; mon "sendkey kp-enter"
  echo "selected automated-test entry"
fi
wait_pat "login:" 300 || echo "(no serial login prompt seen; continuing)"
# give the autologin session plenty of time
sleep 150
shot 04-valtus-desktop-autologin
sleep 30
shot 05-valtus-desktop-welcome
kill "$QPID" "$SPID" "$KPID" 2>/dev/null
ls -la "$OUT"
