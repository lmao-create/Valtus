#!/bin/bash
set -u
W=/root/valtus-inst-test
python3 - "$W/serial.log" <<'PY'
import sys
try:
    raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
except FileNotFoundError:
    print("no log"); sys.exit()
print("log size:", len(raw))
# Show everything from the unattended config write onwards
i = raw.find('unattended.conf')
if i >= 0:
    print(repr(raw[i:i+2500]))
else:
    print("=== tail 2500 ===")
    print(repr(raw[-2500:]))
PY
echo "=== /tmp/inst.log in guest (via disk? no) ==="
ls -la "$W" 2>/dev/null
