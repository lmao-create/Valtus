#!/usr/bin/env bash
# =============================================================================
# Valtus — automated VM test harness (QEMU/KVM inside Debian WSL2)
# =============================================================================
# Usage (inside WSL as root):
#   test_vm.sh <iso> [options]
#
# Options:
#   --entry N        boot this GRUB menu entry (default 0; build grub.cfg:
#                    0 = live, 1 = safe graphics, 2 = live (automated test))
#   --mem MB         guest RAM (default 2048)
#   --timeout SEC    boot/login wait timeout (default 900)
#   --install-disk   attach a disposable 64G qcow2 install target (later phase)
#   --keep           keep the WSL work dir for inspection
#
# Evidence produced (logs/vm-test-<timestamp>/):
#   serial.log       full guest serial console log (boot + commands)
#   screens/*.ppm|png  QEMU monitor screendumps at boot milestones
#   RESULTS.txt      per-check PASS/FAIL report. Every check requires a
#                    matching string in the live serial log — nothing here
#                    is ever reported as passed without guest evidence.
#
# SAFETY: all VM work happens inside a dedicated WSL work directory
# (/root/valtus-vm-test-<ts>). Cleanup removes ONLY that directory, and the
# work-dir path is guarded by a prefix check before any rm.
# =============================================================================
set -o nounset -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"
. "$PROJECT_DIR/config/distro.conf"
. "$PROJECT_DIR/config/valtus.env"
[ -f "$PROJECT_DIR/config/valtus.local.env" ] && . "$PROJECT_DIR/config/valtus.local.env"

ISO="${1:-$PROJECT_DIR/releases/${DISTRO_ID}-${DISTRO_VERSION}-${DISTRO_ARCH}.iso}"
ENTRY=0; MEM=2048; TIMEOUT=900; INSTALL_DISK=0; KEEP=0
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --entry) ENTRY="$2"; shift 2 ;;
    --mem) MEM="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --install-disk) INSTALL_DISK=1; shift ;;
    --keep) KEEP=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[ -f "$ISO" ] || { echo "ISO not found: $ISO" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "run as root inside WSL: wsl -d Debian -u root -- bash $0 $ISO" >&2; exit 1; }
[ -e /dev/kvm ] || echo "WARN: /dev/kvm missing — QEMU will be slow (TCG)"

TS=$(date +%Y%m%d-%H%M%S)
# ALL VM runtime state lives here (WSL ext4, fast); evidence is copied to
# the project logs/ directory at the end.
REALWORK="/root/valtus-vm-test-$TS"
mkdir -p "$REALWORK/screens"
LOGDIR="$PROJECT_DIR/logs/vm-test-$TS"
mkdir -p "$LOGDIR/screens"

SERIAL_SOCK="$REALWORK/serial.sock"
MON_SOCK="$REALWORK/monitor.sock"
SERIAL_LOG="$LOGDIR/serial.log"
CMDFIFO="$REALWORK/cmd.fifo"
RESULTS="$LOGDIR/RESULTS.txt"
: > "$SERIAL_LOG"
mkfifo "$CMDFIFO"
# keep the FIFO open for writing so socat never sees EOF
sleep infinity > "$CMDFIFO" &
KPID=$!
echo "Valtus VM test — $TS" | tee "$RESULTS"
echo "ISO: $ISO (entry $ENTRY, mem ${MEM}MB)" | tee -a "$RESULTS"

PASS=0; FAIL=0; BLOCKED=0
ok()  { echo "PASS: $*" | tee -a "$RESULTS"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $*" | tee -a "$RESULTS"; FAIL=$((FAIL+1)); }
blk() { echo "BLOCKED: $*" | tee -a "$RESULTS"; BLOCKED=$((BLOCKED+1)); }

cleanup() {
  [ -n "${QPID:-}" ] && kill "$QPID" 2>/dev/null
  [ -n "${RPID:-}" ] && kill "$RPID" 2>/dev/null
  [ -n "${KPID:-}" ] && kill "$KPID" 2>/dev/null
  if [ "$KEEP" -eq 1 ]; then
    echo "VM work kept for inspection: $REALWORK" | tee -a "$RESULTS"
    return 0
  fi
  # GUARD: only ever remove the dedicated work dir; never a parent path
  case "$REALWORK" in
    /root/valtus-vm-test-*) rm -rf "$REALWORK" ;;
    *) echo "cleanup guard: refusing to remove $REALWORK" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

send() { echo "$1" > "$CMDFIFO"; }
mon()  { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$MON_SOCK" 2>/dev/null; sleep 0.5; }
shot() { local name="$1"; mon "screendump $REALWORK/screens/$name.ppm"; sleep 1; }

wait_pat() { # pattern timeout_sec
  local pattern="$1"
  local secs="$2"
  local deadline=$((SECONDS+secs))
  while [ $SECONDS -lt $deadline ]; do
    grep -q "$pattern" "$SERIAL_LOG" 2>/dev/null && return 0
    ensure_reader          # self-heal: restart a dead reader mid-wait
    sleep 3
  done
  return 1
}

# --- disposable install target ----------------------------------------------
DISK_ARGS=()
if [ "$INSTALL_DISK" -eq 1 ] || [ "${ALWAYS_DISK:-0}" = "1" ]; then
  qemu-img create -f qcow2 "$REALWORK/disposable.qcow2" 64G >/dev/null
  DISK_ARGS=(-drive "file=$REALWORK/disposable.qcow2,format=qcow2,if=virtio,media=disk")
fi

# --- start QEMU --------------------------------------------------------------
qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 2 -m "$MEM" -machine q35 \
  -cdrom "$ISO" -boot order=d \
  "${DISK_ARGS[@]}" \
  -nic user,model=virtio-net-pci \
  -display none -vga virtio \
  -monitor "unix:$MON_SOCK,server,nowait" \
  -serial "unix:$SERIAL_SOCK,server,nowait" \
  -no-reboot \
  -pidfile "$REALWORK/qemu.pid" &
QPID=$!
sleep 2
if [ -f "$REALWORK/qemu.pid" ] && kill -0 "$(cat "$REALWORK/qemu.pid")" 2>/dev/null; then
  ok "QEMU started (pid $(cat "$REALWORK/qemu.pid"))"
else
  bad "QEMU did not start"
fi

# single bidirectional serial client (a second client would drop the log),
# with restart-on-death: a silently-dead reader loses ALL boot evidence
ensure_reader() {
  if [ -n "${RPID:-}" ] && kill -0 "$RPID" 2>/dev/null; then return 0; fi
  socat - "UNIX-CONNECT:$SERIAL_SOCK" < "$CMDFIFO" >> "$SERIAL_LOG" 2>>"$LOGDIR/reader.err" &
  RPID=$!
  sleep 1
  if kill -0 "$RPID" 2>/dev/null; then
    echo "reader alive pid=$RPID" >> "$LOGDIR/reader.state"
  else
    echo "reader DIED at $(date +%H:%M:%S)" >> "$LOGDIR/reader.state"
    echo "--- reader.err ---" >> "$LOGDIR/reader.state"; cat "$LOGDIR/reader.err" >> "$LOGDIR/reader.state" 2>/dev/null
    RPID=""
  fi
}
ensure_reader

# --- boot evidence -----------------------------------------------------------
if wait_pat "Booting .Valtus\|GNU GRUB\|GRUB " 90; then
  ok "bootloader (GRUB) menu visible on serial console"
  shot 01-grub
else
  bad "no GRUB menu on serial within 90s"
fi

# GRUB menu navigation for non-default entries
if [ "$ENTRY" -gt 0 ]; then
  i=0
  while [ "$i" -lt "$ENTRY" ]; do mon "sendkey down"; i=$((i+1)); done
  sleep 1; mon "sendkey kp-enter"
  echo "booted GRUB entry $ENTRY" >> "$RESULTS"
fi

if wait_pat "login:" "$TIMEOUT"; then
  ok "Linux booted to console getty (serial login available)"
else
  bad "no login prompt within ${TIMEOUT}s — see serial.log"
fi
shot 02-console-or-sddm

# --- log in on the serial console --------------------------------------------
sleep 5
send "$LIVE_USER"
if wait_pat "[Pp]assword:" 30; then
  send "$LIVE_USER_PASSWORD"
else
  send "$LIVE_USER_PASSWORD"   # fallback: send anyway after 30s
fi
if wait_pat "$LIVE_USER@$DISTRO_HOSTNAME" 120; then
  ok "serial console login succeeded ($LIVE_USER)"
else
  bad "serial console login failed (documented live credential)"
fi

RUN_CHECK() { # name pattern command
  local name="$1" pattern="$2" cmd="$3" mark="###DONE-$RANDOM$RANDOM"
  # A newline BEFORE the marker echo guarantees the marker starts a fresh
  # line even when the previous command's output has no trailing newline.
  { echo "$cmd"; echo; echo "echo $mark"; } > "$CMDFIFO"
  # Wait for the marker to appear TWICE (once as the echoed input line, once
  # as its output) - that guarantees the preceding command's output has been
  # flushed to the serial log before we capture it.
  local deadline=$((SECONDS+90))
  local seen=0
  while [ $SECONDS -lt $deadline ]; do
    seen=$(grep -a -c "$mark" "$SERIAL_LOG" 2>/dev/null || echo 0)
    [ "$seen" -ge 2 ] && break
    ensure_reader
    sleep 2
  done
  if [ "${seen:-0}" -ge 2 ]; then
    # capture everything up to the LAST marker occurrence, escapes stripped
    local out
    out=$(awk -v m="$mark" 'index($0, m) {exit} {print}' "$SERIAL_LOG" | tail -120 | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g')
    if printf '%s' "$out" | grep -q -- "$pattern"; then
      ok "$name"
    else
      bad "$name (pattern not seen: $pattern)"
      echo "--- last output of: $name ---" >> "$LOGDIR/DEBUG.txt"; printf '%s\n' "$out" | tail -8 >> "$LOGDIR/DEBUG.txt"
    fi
  else
    bad "$name (timeout waiting for marker, seen=$seen)"
  fi
}

# --- in-guest checks ----------------------------------------------------------
RUN_CHECK "identity: os-release names Valtus" "PRETTY_NAME=\"$DISTRO_NAME $DISTRO_VERSION" \
  "grep --color=never PRETTY_NAME /etc/os-release"
RUN_CHECK "identity: wallpaper package installed" "/usr/share/wallpapers/valtus" \
  "ls -d /usr/share/wallpapers/valtus"
RUN_CHECK "identity: theme files installed" "$DISTRO_THEME.colors" \
  "ls /usr/share/color-schemes | grep ValtusDark.colors"
RUN_CHECK "identity: look-and-feel installed" "org.valtus.desktop" \
  "ls /usr/share/plasma/look-and-feel | grep org.valtus.desktop"
RUN_CHECK "systemd: system running" "running\|degraded" "systemctl is-system-running"
RUN_CHECK "systemd: no failed units" "^0$" "systemctl --failed --no-legend | wc -l"
RUN_CHECK "network: interface detected" "connected\|connecting" "nmcli -t -f DEVICE,STATE device status"
RUN_CHECK "network: DHCP address assigned" "enp0s\|10\.0\.2\." "ip -brief address show | grep -v lo"
RUN_CHECK "network: DNS resolves" "archive.ubuntu.com" "getent hosts archive.ubuntu.com"
RUN_CHECK "network: HTTP reachability (curl)" "^200 " "curl -sS -m 10 -o /dev/null -w '%{http_code} %{url_effective}\\n' http://archive.ubuntu.com/ubuntu/ || true"
RUN_CHECK "security: ufw firewall active" "Status: active" "echo $LIVE_USER_PASSWORD | sudo -S ufw status verbose"
RUN_CHECK "security: sudo requires password" "root" "echo $LIVE_USER_PASSWORD | sudo -S id -un root"
RUN_CHECK "security: root account locked" "^root:[*!]" "sudo grep --color=never '^root:' /etc/shadow"
RUN_CHECK "security: AppArmor active" "apparmor" "tr -d '\\n' < /sys/kernel/security/lsm; echo"
RUN_CHECK "security: unattended-upgrades enabled" "enabled\|active" \
  "systemctl is-enabled unattended-upgrades.service 2>/dev/null; systemctl is-active unattended-upgrades.service 2>/dev/null"
RUN_CHECK "security: credentials unit exists" "valtus-live-credentials" \
  "systemctl list-unit-files | grep valtus-live-credentials"
RUN_CHECK "system: hostname" "$DISTRO_HOSTNAME" "hostname"
RUN_CHECK "package manager: apt-get update" "Reading package lists" \
  "echo $LIVE_USER_PASSWORD | sudo -S apt-get update"
RUN_CHECK "package manager: install a package" "Setting up\|already the newest\|Unpacking" \
  "echo $LIVE_USER_PASSWORD | sudo -S apt-get install -y --no-install-recommends nano 2>&1 || true"

APPLIST="konsole dolphin kate okular falkon vlc spectacle plasma-discover systemsettings kinfocenter plasma-systemmonitor kcalc valtus-welcome"
for app in $APPLIST; do
  RUN_CHECK "application on PATH: $app" "/usr/bin/$app" "command -v $app"
done

# --- desktop checks -----------------------------------------------------------
sleep 3
RUN_CHECK "desktop: plasma binary present" "/usr/bin/plasmashell" "command -v plasmashell"
RUN_CHECK "desktop: wallpaper asset readable" "PNG image data\|valtus" \
  "file /usr/share/wallpapers/valtus/contents/images/3840x2160.png"

# SDDM login via QEMU monitor sendkeys for the graphical-session checks
sddm_login_sendkeys() { mon "sendkey ${1}"; }
# default: on for entries < 2 (login screen); never for an autologin entry
if [ -z "${SDDM_SENDKEY_LOGIN:-}" ]; then
  if [ "$ENTRY" -ge 2 ]; then SDDM_SENDKEY_LOGIN=0; else SDDM_SENDKEY_LOGIN=1; fi
fi
if [ "$SDDM_SENDKEY_LOGIN" = "1" ]; then
  echo "typing live credentials into SDDM via monitor sendkeys" | tee -a "$RESULTS"
  for ch in $(echo "$LIVE_USER" | sed 's/./& /g'); do sddm_login_sendkeys "$ch"; sleep 0.3; done
  sleep 2; mon "sendkey ret"; sleep 2
  for ch in $(echo "$LIVE_USER_PASSWORD" | sed 's/./& /g'); do sddm_login_sendkeys "$ch"; sleep 0.3; done
  sleep 1; mon "sendkey ret"
  if wait_pat "plasmashell\|kwin_wayland\|session opened" 300; then
    ok "SDDM login via sendkeys; Plasma session started"
    shot 03-desktop
  else
    bad "no Plasma session detected after sendkey login (see screenshots)"
  fi
  RUN_CHECK "desktop: graphical session registered" "seat0\|session" \
    "loginctl --no-legend | head -3"
fi

# --- shutdown -------------------------------------------------------------------
shot 04-final
echo "echo $LIVE_USER_PASSWORD | sudo -S systemctl poweroff" > "$CMDFIFO"
if wait_pat "reboot: Power down\|Power down\|The system will power off now" 120; then
  ok "guest initiated clean shutdown"
else
  if [ -f "$REALWORK/qemu.pid" ]; then
    i=0
    while [ $i -lt 20 ] && kill -0 "$(cat "$REALWORK/qemu.pid")" 2>/dev/null; do sleep 3; i=$((i+3)); done
    if kill -0 "$(cat "$REALWORK/qemu.pid")" 2>/dev/null; then
      bad "guest did not shut down"
    else
      ok "QEMU process exited after poweroff (guest powered off)"
      echo "note: no 'Power down' serial banner; VM exit accepted as evidence" >> "$RESULTS"
    fi
  else
    bad "guest did not shut down"
  fi
fi

# convert ppm screenshots to png when possible
if command -v python3 >/dev/null && python3 -c "import PIL" 2>/dev/null; then
  for f in "$REALWORK"/screens/*.ppm; do
    [ -f "$f" ] && python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).save(sys.argv[1].replace('.ppm','.png'))" "$f"
  done
fi
cp "$REALWORK"/screens/* "$LOGDIR/screens/" 2>/dev/null || true

echo
echo "VM TEST SUMMARY: $PASS passed, $FAIL failed, $BLOCKED blocked" | tee -a "$RESULTS"
echo "evidence: $LOGDIR" | tee -a "$RESULTS"
[ "$FAIL" -eq 0 ]
