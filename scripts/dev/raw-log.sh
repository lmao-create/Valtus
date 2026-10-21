#!/bin/bash
set -u
L=$(ls -t /mnt/c/Users/hp/Desktop/Custom\ OS/logs/vm-test-*/serial.log | head -1)
echo "log: $L"
echo "=== bytes around the first Password: (visible control chars) ==="
grep -a -n "Password:" "$L" | head -3
python3 - "$L" <<'PY'
import sys, re
raw = open(sys.argv[1], 'rb').read()
# find first "valtus login:" and show 600 bytes around it
i = raw.find(b'valtus login:')
seg = raw[i:i+400] if i >= 0 else raw[:400]
print(repr(seg))
PY
