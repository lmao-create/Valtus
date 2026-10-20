#!/bin/bash
# Diagnose the live credentials unit: boot the ISO verbosely, log in on the
# serial console (empty password — casper keeps user-setup's empty hash when
# sddm is present), and inspect the unit/journal/shadow/sddm state.
set -o nounset -o pipefail

B=/root/valtus-build
R=$B/work/rootfs
KVER=6.8.0-147-generic
W=/root/valtus-dbg3
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
  -cdrom "/mnt/c/Users/hp/Desktop/Custom OS/releases/valtus-0.1.0-amd64.iso" -boot order=d \
  -nic user,model=virtio-net-pci \
  -display none -vga virtio \
  -serial "unix:$S_SOCK,server,nowait" \
  -no-reboot -pidfile "$W/qemu.pid" &
QPID=$!
sleep 2

socat - "UNIX-CONNECT:$S_SOCK" < "$FIFO" >> "$LOG" 2>/dev/null &
SPID=$!

send() { echo "$1" > "$FIFO"; sleep 1.5; }
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

if ! wait_pat "valtus login:" 300; then
  echo "FAIL: no login prompt"; tail -20 "$LOG"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1
fi
echo "PASS: login prompt reached"

# try empty password first (casper's user-setup hash), then the documented one
send "valtus"
send ""
if ! wait_pat 'valtus@valtus' 30; then
  echo "empty password rejected; trying documented password"
  send "valtus"
  send "valtus"
  if ! wait_pat 'valtus@valtus' 30; then
    echo "FAIL: cannot log in either way"; kill "$QPID" "$SPID" "$KPID" 2>/dev/null; exit 1
  fi
fi
echo "PASS: logged in on serial console"

send "echo ===UNIT===; systemctl status valtus-live-credentials.service --no-pager | head -20"
send "echo ===JOURNAL===; journalctl -u valtus-live-credentials.service --no-pager | tail -25"
send "echo ===SHADOW===; sudo grep valtus /etc/shadow | cut -c1-20"
send "echo ===SDDM-CONF===; cat /etc/sddm.conf 2>/dev/null; ls -la /etc/sddm.conf.d/ 2>/dev/null"
send "echo ===CONDITION===; systemd-analyze cat-config systemd/system/valtus-live-credentials.service 2>/dev/null | head -20"
send "echo ===SCRIPT===; ls -la /usr/lib/valtus/live-credentials; head -8 /usr/lib/valtus/live-credentials"
send "echo ===PASSWD-DB===; grep valtus /etc/passwd"
sleep 12
echo "poweroff" > "$FIFO"
sleep 5
kill "$QPID" "$SPID" "$KPID" 2>/dev/null

echo
echo "=== diagnostics ==="
sed -n '/===UNIT===/,$p' "$LOG" | head -60
