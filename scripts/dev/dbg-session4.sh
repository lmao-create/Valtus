#!/bin/bash
# Lean: does KWin/plasmashell ever come up in the autologin session?
set -o nounset -o pipefail

P="/mnt/c/Users/hp/Desktop/Custom OS"
. "$P/config/distro.conf"
. "$P/config/valtus.env"

R=/root/valtus-build/work/rootfs
KVER=6.8.0-147-generic
W=/root/valtus-dbg4
rm -rf "$W"; mkdir -p "$W"

FIFO="$W/cmd.fifo"
: > "$W/serial.log"
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
  -serial "unix:$W/serial.sock,server,nowait" \
  -no-reboot -pidfile "$W/qemu.pid" &
QPID=$!
sleep 2
echo "qemu pid $(cat $W/qemu.pid 2>/dev/null)"

socat - "UNIX-CONNECT:$W/serial.sock" < "$FIFO" >> "$W/serial.log" 2>/dev/null &
SPID=$!

send() { echo "$1" > "$FIFO"; sleep 2; }
wait_pat() {
  local pattern="$1"; local secs="$2"; local deadline=$((SECONDS+secs))
  while [ $SECONDS -lt $deadline ]; do
    grep -q "$pattern" "$W/serial.log" 2>/dev/null && return 0
    sleep 2
  done
  return 1
}

# serial login (prompt appears ~90s after boot)
wait_pat "login:" 150 || { echo "no prompt"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1; }
send "valtus"; sleep 3; send "$LIVE_USER_PASSWORD"
wait_pat 'valtus@valtus' 45 || { echo "no login"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1; }
echo "== logged in =="
send "ps aux | grep -iE 'kwin|plasmashell|startplasma|Xsession' | grep -v grep"
send "journalctl -b --no-pager | grep -iE 'kwin|plasmashell|startplasma' | tail -8"
send "journalctl -b --no-pager | grep -iE 'Session.*valtus|Failed|error' | tail -8"
sleep 15
kill "$QPID" "$SPID" "$KPID" 2>/dev/null
echo "== data =="
awk '/^\[?2004hvaltus@valtus/{c++} c>=3' "$W/serial.log" | head -50
