#!/bin/bash
# Why does the autologin session stall after Xorg? Full process tree,
# Xsession progress, Xorg log tail, user journal.
set -o nounset -o pipefail

P="/mnt/c/Users/hp/Desktop/Custom OS"
. "$P/config/distro.conf"
. "$P/config/valtus.env"

R=/root/valtus-build/work/rootfs
KVER=6.8.0-147-generic
W=/root/valtus-dbg3
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

socat - "UNIX-CONNECT:$W/serial.sock" < "$FIFO" >> "$W/serial.log" 2>/dev/null &
SPID=$!

send() { echo "$1" > "$FIFO"; sleep 2; }
wait_pat() {
  local pattern="$1"; local secs="$2"; local deadline=$((SECONDS+secs))
  while [ $SECONDS -lt $deadline ]; do
    grep -q "$pattern" "$W/serial.log" 2>/dev/null && return 0
    sleep 3
  done
  return 1
}

wait_pat "login:" 300
sleep 30   # let the autologin session settle
send "valtus"; sleep 3; send "$LIVE_USER_PASSWORD"
if ! wait_pat 'valtus@valtus' 60; then echo "FAIL: serial login"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1; fi
echo "== dumping =="
send "echo ==TREE==; ps -ef --forest | grep -A6 -B2 'Xorg\|sddm-helper' | head -30"
send "echo ==KPGREP==; ps aux | grep -iE 'kwin|plasma|Xsession' | grep -v grep"
send "echo ==XERR==; tail -5 /home/valtus/.xsession-errors 2>/dev/null || echo no-xsession-errors"
send "echo ==XORGLOG==; tail -5 /home/valtus/.local/share/xorg/Xorg.0.log 2>/dev/null"
send "echo ==USERJOURNAL==; journalctl --user -b --no-pager 2>/dev/null | tail -20 || journalctl -b --no-pager | grep -i 'plasma\|kwin' | tail -10"
sleep 20
kill "$QPID" "$SPID" "$KPID" 2>/dev/null
awk '/==TREE==/{f=1} f' "$W/serial.log" | head -70
