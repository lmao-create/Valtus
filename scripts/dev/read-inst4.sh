#!/bin/bash
set -u
W=/root/valtus-inst-test
echo "=== inst-test dir ==="
ls -la "$W" 2>/dev/null
echo "=== live-install evidence (archived) ==="
LATEST=$(ls -dt /mnt/c/Users/hp/Desktop/Custom\ OS/logs/installer-test-* 2>/dev/null | head -1)
echo "dir: $LATEST"
ls -la "$LATEST" 2>/dev/null
echo "=== serial content of the live install ==="
python3 - "$W/serial.log" <<'PY'
import sys
try:
    raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
except FileNotFoundError:
    print("no serial.log"); sys.exit()
print("len:", len(raw))
import re
clean = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', raw)
clean = clean.replace('\r', '')
# show the tail
print(clean[-2000:])
PY
