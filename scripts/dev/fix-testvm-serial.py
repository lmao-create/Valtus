#!/usr/bin/env python3
"""Convert test_vm.sh's serial handling to a single bidirectional client
(FIFO pattern) so sending input never drops the log reader."""
import sys

path = "/mnt/c/Users/hp/Desktop/Custom OS/scripts/test_vm.sh"
with open(path, encoding="utf-8", newline="") as f:
    src = f.read()

if "cmd.fifo" in src:
    print("already applied")
    sys.exit(0)

changes = [
    # 1) create FIFO + keep-open next to the socket vars
    ('''SERIAL_LOG="$LOGDIR/serial.log"
RESULTS="$LOGDIR/RESULTS.txt"
: > "$SERIAL_LOG"''',
     '''SERIAL_LOG="$LOGDIR/serial.log"
CMDFIFO="$REALWORK/cmd.fifo"
RESULTS="$LOGDIR/RESULTS.txt"
: > "$SERIAL_LOG"
mkfifo "$CMDFIFO"
# keep the FIFO open for writing so socat never sees EOF
sleep infinity > "$CMDFIFO" &
KPID=$!'''),

    # 2) reader + senders become ONE bidirectional client
    ('''# persistent serial reader (keeps the socket drained)
socat -u "UNIX-CONNECT:$SERIAL_SOCK" "OPEN:$SERIAL_LOG,creat,append" 2>/dev/null &
RPID=$!''',
     '''# single bidirectional serial client (a second client would drop the log)
socat - "UNIX-CONNECT:$SERIAL_SOCK" < "$CMDFIFO" >> "$SERIAL_LOG" 2>/dev/null &
RPID=$!'''),

    ('''send() { printf '%s\\n' "$1" | socat - "UNIX-CONNECT:$SERIAL_SOCK" 2>/dev/null; }''',
     '''send() { echo "$1" > "$CMDFIFO"; }'''),

    ('''mon()  { printf '%s\\n' "$1" | socat - "UNIX-CONNECT:$MON_SOCK" 2>/dev/null; sleep 0.5; }''',
     '''mon()  { printf '%s\\n' "$1" | socat - "UNIX-CONNECT:$MON_SOCK" 2>/dev/null; sleep 0.5; }'''),

    # 3) RUN_CHECK / poweroff send through the FIFO too
    ('''  printf '%s\\n' "$cmd; echo $mark" | socat - "UNIX-CONNECT:$SERIAL_SOCK" 2>/dev/null''',
     '''  { echo "$cmd"; echo "echo $mark"; } > "$CMDFIFO"'''),

    ('''printf '%s\\n' "echo $LIVE_USER_PASSWORD | sudo -S systemctl poweroff" | \\
  socat - "UNIX-CONNECT:$SERIAL_SOCK" 2>/dev/null''',
     '''echo "echo $LIVE_USER_PASSWORD | sudo -S systemctl poweroff" > "$CMDFIFO"'''),

    # 4) cleanup also stops the fifo keeper
    ('''cleanup() {
  [ -n "${QPID:-}" ] && kill "$QPID" 2>/dev/null
  [ -n "${RPID:-}" ] && kill "$RPID" 2>/dev/null''',
     '''cleanup() {
  [ -n "${QPID:-}" ] && kill "$QPID" 2>/dev/null
  [ -n "${RPID:-}" ] && kill "$RPID" 2>/dev/null
  [ -n "${KPID:-}" ] && kill "$KPID" 2>/dev/null'''),
]

for old, new in changes:
    if src.count(old) != 1:
        print(f"anchor problem ({src.count(old)}): {old[:60]!r}")
        sys.exit(1)
    src = src.replace(old, new)

with open(path, "w", encoding="utf-8", newline="") as f:
    f.write(src)
print("test_vm.sh serial I/O patched")
