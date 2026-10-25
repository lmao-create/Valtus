#!/bin/bash
set -u
W=/root/valtus-inst-test
L="$W/serial.log"
echo "=== log size: $(wc -c < "$L" 2>/dev/null || echo 0) bytes ==="
echo "=== the valtus-install invocation and its output ==="
python3 - "$L" <<'PY'
import sys
try:
    raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
except FileNotFoundError:
    print("no log"); sys.exit()
# find the installer command
i = raw.find('valtus-install')
if i >= 0:
    print(repr(raw[i-200:i+900]))
else:
    print("valtus-install command not in log")
    print("=== tail ===")
    print(repr(raw[-800:]))
PY
