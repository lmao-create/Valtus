#!/bin/bash
set -u
L=$(ls -t /mnt/c/Users/hp/Desktop/Custom\ OS/logs/vm-test-*/serial.log | head -1)
python3 - "$L" <<'PY'
import sys
raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
i = raw.find('systemctl poweroff')
print(repr(raw[i-120:i+400]) if i >= 0 else "poweroff command not found")
PY
