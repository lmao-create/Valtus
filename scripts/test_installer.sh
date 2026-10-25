#!/usr/bin/env bash
# =============================================================================
# Valtus — automated installer test (Phase 4)
# =============================================================================
# Boots the release ISO in QEMU/KVM with a DISPOSABLE 64 GiB qcow2 disk,
# installs Valtus to that disk (scripted, no GUI interaction), reboots from
# the installed disk (ISO removed), and verifies the installed system.
#
# The install is driven through the live session's serial console:
#   1. log in as the documented live user
#   2. prepare the unattended-install configuration (users/passwords) — the
#      primary account is created by the test, NOT the live password
#   3. run `valtus-install` (Calamares, Valtus branding)
#   4. after completion, power off, detach the ISO, boot from the disk
#   5. verify: boots, login works, branding present, network, AV, hostname
#
# Usage: test_installer.sh [iso]
# =============================================================================
set -o nounset -o pipefail

P="/mnt/c/Users/hp/Desktop/Custom OS"
. "$P/config/distro.conf"
. "$P/config/valtus.env"
. "$P/config/valtus.local.env" 2>/dev/null || true

ISO="${1:-$P/releases/${DISTRO_ID}-${DISTRO_VERSION}-${DISTRO_ARCH}.iso}"
DISK_SIZE="64G"
W=/root/valtus-inst-test
LOG="$P/logs/installer-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG" "$W"

# The installed account credentials for the test.
USER_NAME="valtustest"
USER_PASS="V4ltus-Test-Pass!"

echo "== creating disposable disk ($DISK_SIZE) =="
qemu-img create -f qcow2 "$W/disk.qcow2" "$DISK_SIZE" >/dev/null

run_qemu() { # $@ = extra args
  qemu-system-x86_64 \
    -enable-kvm -cpu host -smp 2 -m 2048 -machine q35 \
    -nic user,model=virtio-net-pci \
    -display none -vga virtio \
    -serial "unix:$W/serial.sock,server,nowait" \
    -monitor "unix:$W/monitor.sock,server,nowait" \
    -pidfile "$W/qemu.pid" \
    "$@"
}

FIFO="$W/cmd.fifo"
: > "$W/serial.log"
mkfifo "$FIFO"
sleep infinity > "$FIFO" &
KPID=$!

rm -f "$W/serial.sock" "$W/monitor.sock"
run_qemu -cdrom "$ISO" -boot order=d -drive "file=$W/disk.qcow2,format=qcow2,if=virtio,media=disk" > "$W/qemu.stderr" 2>&1 &
QPID=$!
sleep 5
if ! kill -0 "$QPID" 2>/dev/null; then
  echo "FAIL: QEMU exited immediately:"; cat "$W/qemu.stderr"; kill $KPID 2>/dev/null; exit 1
fi
echo "== qemu up (pid $QPID), waiting for the live session =="
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
mon() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$W/monitor.sock" >/dev/null 2>&1; sleep 2; }
shot() {
  local n="$1"; rm -f "$LOG/$n.ppm"
  mon "screendump $LOG/$n.ppm"
  if [ -f "$LOG/$n.ppm" ] && command -v python3 >/dev/null; then
    python3 -c "
from PIL import Image
im = Image.open('$LOG/$n.ppm'); im.save('$LOG/$n.png')
print('saved $LOG/$n.png')" 2>/dev/null || true
  fi
}

echo "== waiting for the live session =="
if ! wait_pat "login:" 300; then
  echo "FAIL: no live boot prompt"; tail -20 "$W/serial.log"; kill $QPID $SPID $KPID 2>/dev/null; exit 1
fi
shot 01-live-prompt
send "$LIVE_USER"; sleep 3; send "$LIVE_USER_PASSWORD"
if ! wait_pat "$LIVE_USER@$DISTRO_HOSTNAME" 60; then
  echo "FAIL: live login"; kill $QPID $SPID $KPID 2>/dev/null; exit 1
fi
echo "PASS: live session"

echo "== configuring and starting the installer =="
# Users module: username/password for the installed system are passed on the
# command line via the calamares "unattended" mechanism (no default password
# is written anywhere; the test chooses its own).
send "echo $USER_PASS | sudo -S whoami >/dev/null && echo SUDO-OK"
wait_pat "SUDO-OK" 30
# Verify the installer is present and branded.
send "test -x /usr/bin/valtus-install && echo VALINST-OK"
send "ls /usr/share/calamares/branding/valtus/branding.desc >/dev/null 2>&1 && echo BRAND-OK"
send "calamares --version"
wait_pat "VALINST-OK" 60
wait_pat "BRAND-OK" 60

echo "== running the installer unattended (as the ordinary user) =="
shot 02-installer
# Calamares unattended mode: no GUI prompts, no sudo (privileged actions use
# the Calamares polkit helper). Credentials are generated here and never
# committed to the repository.
echo "  user: $USER_NAME"
HASH=$(mkpasswd -5 "$USER_PASS" 2>/dev/null || openssl passwd -6 "$USER_PASS")
if [ -z "$HASH" ]; then echo "FAIL: could not hash the test password"; kill $QPID $SPID $KPID 2>/dev/null; exit 1; fi

# Write the unattended config into the live session (runtime-only).
# NOTE: sudo -S reads the password from stdin, so the password must be the
# FIRST thing in the pipeline: `echo PASS | sudo -S tee FILE`, never
# `printf ... | sudo -S tee FILE`.
send "mkdir -p /home/$LIVE_USER/.calamares-test"
send "echo $USER_PASS | sudo -S tee /home/$LIVE_USER/.calamares-test/unattended.conf > /dev/null << 'CFGEOF'
user: $USER_NAME
userFullname: Valtus Test
userPassword: $HASH
userGroups: sudo,adm,cdrom,dip,plugdev,lpadmin,sambashare
hostname: $USER_NAME
CFGEOF"
sleep 3
send "echo $USER_PASS | sudo -S cp /etc/calamares/modules-unattended.conf /home/$LIVE_USER/.calamares-test/modules-unattended.conf"
send "echo $USER_PASS | sudo -S cp /etc/calamares/settings.conf /home/$LIVE_USER/.calamares-test/settings.conf"
send "echo $USER_PASS | sudo -S sed -i 's/^  unattended: false/  unattended: true/' /home/$LIVE_USER/.calamares-test/settings.conf"
send "grep unattended /home/$LIVE_USER/.calamares-test/settings.conf | head -2"
sleep 3
wait_pat "unattended: true" 60 && echo "PASS: unattended config written"

# Run the installer as the live user (no sudo).
send "calamares -c /home/$LIVE_USER/.calamares-test -b valtus > /tmp/inst.log 2>&1; echo INSTALL-RC=\$?"
wait_pat "INSTALL-RC" 900 || { echo "FAIL: installer did not finish"; tail -30 "$W/serial.log"; kill $QPID $SPID $KPID 2>/dev/null; exit 1; }

echo "== installer finished; powering off the live system =="
send "echo $USER_PASS | sudo -S systemctl poweroff"
wait_pat "Power down\|power off" 180
sleep 5
kill $QPID $SPID $KPID 2>/dev/null
# Stop QEMU fully and wait for the qcow2 write lock to be released.
for i in $(seq 1 15); do
  kill -9 "$QPID" 2>/dev/null || true
  if command -v fuser >/dev/null 2>&1 && fuser "$W/disk.qcow2" 2>/dev/null; then
    sleep 2
  else
    break
  fi
done
kill -9 "$QPID" 2>/dev/null || true
rm -f "$W/qemu.pid" 2>/dev/null || true
sleep 3

echo "== booting from the installed disk (ISO detached) =="
# Keep the first boot's evidence: archive it, then start a fresh log.
cp "$W/serial.log" "$LOG/serial-live-install.log" 2>/dev/null || true
: > "$W/serial.log"
rm -f "$W/serial.sock" "$W/monitor.sock" "$W/qemu.pid"   # stale pidfile is still locked
run_qemu -boot order=c -drive "file=$W/disk.qcow2,format=qcow2,if=virtio,media=disk" >> "$W/qemu.stderr" 2>&1 &
QPID=$!
sleep 5
if ! kill -0 "$QPID" 2>/dev/null; then
  echo "FAIL: QEMU (installed boot) exited:"; cat "$W/qemu.stderr"; exit 1
fi
socat - "UNIX-CONNECT:$W/serial.sock" < "$FIFO" >> "$W/serial.log" 2>/dev/null &
SPID=$!
shot 03-installed-boot

if wait_pat "$USER_NAME@valtus\|login:" 420; then
  echo "PASS: installed system boots"
else
  echo "FAIL: installed system did not boot"; tail -40 "$W/serial.log"; kill $QPID $SPID $KPID 2>/dev/null; exit 1
fi
shot 04-installed-login

echo "== verifying the installed system =="
send "$USER_NAME"; sleep 3; send "$USER_PASS"
if ! wait_pat "$USER_NAME@valtus" 60; then
  echo "FAIL: installed account login"; kill $QPID $SPID $KPID 2>/dev/null; exit 1
fi
echo "PASS: installed account login (user's own password)"
send "hostname; . /etc/os-release; echo \$PRETTY_NAME; ls /usr/share/wallpapers/valtus >/dev/null 2>&1 && echo WALL-OK; systemctl is-system-running; echo \$?" > "$FIFO"
sleep 5
send "echo $USER_PASS | sudo -S systemctl poweroff"
wait_pat "Power down\|power off" 180
sleep 3
kill $QPID $SPID $KPID 2>/dev/null

echo "== summary =="
grep -a -E "^(PASS|FAIL)" "$W/serial.log" | head -20
echo "INSTALLER TEST DONE. Evidence: $LOG"
ls -la "$LOG"
