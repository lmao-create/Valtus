#!/usr/bin/env python3
"""Fix test_vm.sh check logic:
 1. RUN_CHECK: capture everything up to the marker with awk (handles output
    with no trailing newline) and strip ANSI escape sequences,
 2. run color-sensitive commands with --color=never / cat,
 3. corrected patterns (id -un root -> root; root lock root:[*!]; failed units
    count 0; spectacle binary),
 4. ufw-root check via sudo (it requires root),
 5. network: drop ping (iputils-ping not installed), use curl for reachability,
 6. mkdir -p logs/screens so evidence survives the cleanup.
"""
import sys

path = "/mnt/c/Users/hp/Desktop/Custom OS/scripts/test_vm.sh"
with open(path, encoding="utf-8", newline="") as f:
    src = f.read()

edits = []

# 1) robust output capture: awk up to the marker, strip ANSI, then match
edits.append((
    '''RUN_CHECK() { # name pattern command
  local name="$1" pattern="$2" cmd="$3" mark="###DONE-$RANDOM$RANDOM"
  { echo "$cmd"; echo "echo $mark"; } > "$CMDFIFO"
  if wait_pat "$mark" 60 && sed -n "/$mark/!p" "$SERIAL_LOG" | tail -40 | grep -q -- "$pattern"; then
    ok "$name"
  else
    bad "$name (pattern not seen: $pattern)"
  fi
}''',
    '''RUN_CHECK() { # name pattern command
  local name="$1" pattern="$2" cmd="$3" mark="###DONE-$RANDOM$RANDOM"
  { echo "$cmd"; echo "echo $mark"; } > "$CMDFIFO"
  if wait_pat "$mark" 90; then
    # everything written before the marker, ANSI escapes stripped
    local out
    out=$(awk -v m="$mark" 'index($0, m) {exit} {print}' "$SERIAL_LOG" | tail -60 | sed 's/\\x1b\\[[0-9;?]*[a-zA-Z]//g')
    if printf '%s' "$out" | grep -q -- "$pattern"; then
      ok "$name"
    else
      bad "$name (pattern not seen: $pattern)"
      echo "--- last output ---" >> "$LOGDIR/DEBUG.txt"; printf '%s\\n' "$out" | tail -5 >> "$LOGDIR/DEBUG.txt"
    fi
  else
    bad "$name (timeout waiting for marker)"
  fi
}'''))

# 2) os-release: avoid colorized grep output
edits.append((
    '''RUN_CHECK "identity: os-release names Valtus" "PRETTY_NAME=\\"$DISTRO_NAME $DISTRO_VERSION" \\
  "grep PRETTY_NAME /etc/os-release"''',
    '''RUN_CHECK "identity: os-release names Valtus" "PRETTY_NAME=\\"$DISTRO_NAME $DISTRO_VERSION" \\
  "grep --color=never PRETTY_NAME /etc/os-release"'''))

# 3) failed-units count: wc -l prints just a number
edits.append((
    '''RUN_CHECK "systemd: no failed units" "0 loaded units listed" "systemctl --failed --no-legend | wc -l"''',
    '''RUN_CHECK "systemd: no failed units" "^0$" "systemctl --failed --no-legend | wc -l"'''))

# 4) sudo check: id -un root prints "root"
edits.append((
    '''RUN_CHECK "security: sudo requires password" "uid=0(root)" "echo $LIVE_USER_PASSWORD | sudo -S id -un root"''',
    '''RUN_CHECK "security: sudo requires password" "root" "echo $LIVE_USER_PASSWORD | sudo -S id -un root"'''))

# 5) root lock: '*' or '!' both mean locked
edits.append((
    '''RUN_CHECK "security: root account locked" "^root:!" "sudo grep '^root:' /etc/shadow"''',
    '''RUN_CHECK "security: root account locked" "^root:[*!]" "sudo grep --color=never '^root:' /etc/shadow"'''))

# 6) ufw needs root
edits.append((
    '''RUN_CHECK "security: ufw firewall active" "Status: active" "ufw status verbose"''',
    '''RUN_CHECK "security: ufw firewall active" "Status: active" "echo $LIVE_USER_PASSWORD | sudo -S ufw status verbose"'''))

# 7) spectacle binary name
edits.append((
    '''APPLIST="konsole dolphin kate okular falkon vlc kde-spectacle plasma-discover systemsettings kinfocenter plasma-systemmonitor kcalc valtus-welcome"''',
    '''APPLIST="konsole dolphin kate okular falkon vlc spectacle plasma-discover systemsettings kinfocenter plasma-systemmonitor kcalc valtus-welcome"'''))

# 8) ping not installed -> use curl for reachability (DNS test already covers resolution)
edits.append((
    '''RUN_CHECK "network: ping external host" "1 received" "ping -c1 -W5 archive.ubuntu.com"''',
    '''RUN_CHECK "network: HTTP reachability (curl)" "HTTP/\\|200 OK" "curl -sS -m 10 -o /dev/null -w '%{http_code} %{url_effective}\\\\n' http://archive.ubuntu.com/ubuntu/ || true"'''))

# 9) AppArmor check: strip prompt escapes by using od-free approach
edits.append((
    '''RUN_CHECK "security: AppArmor active" "apparmor" "cat /sys/kernel/security/lsm"''',
    '''RUN_CHECK "security: AppArmor active" "apparmor" "tr -d '\\\\n' < /sys/kernel/security/lsm; echo"'''))

# 10) preserve screenshots
edits.append((
    '''LOGDIR="$PROJECT_DIR/logs/vm-test-$TS"
mkdir -p "$LOGDIR"''',
    '''LOGDIR="$PROJECT_DIR/logs/vm-test-$TS"
mkdir -p "$LOGDIR/screens"'''))

for old, new in edits:
    if src.count(old) != 1:
        print(f"anchor problem ({src.count(old)}): {old[:70]!r}")
        sys.exit(1)
    src = src.replace(old, new)

with open(path, "w", encoding="utf-8", newline="") as f:
    f.write(src)
print("test_vm.sh harness checks patched")
