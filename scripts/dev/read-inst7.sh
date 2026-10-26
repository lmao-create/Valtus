#!/bin/bash
set -u
LATEST=$(ls -dt /mnt/c/Users/hp/Desktop/Custom\ OS/logs/installer-test-* | head -1)
echo "dir: $LATEST"
python3 - "$LATEST/serial-live-install.log" <<'PY'
import sys, re
try:
    raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
except FileNotFoundError:
    print("missing"); sys.exit()
clean = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', raw).replace('\r', '')
i = clean.find('INSTALL-RC')
print(clean[max(0,i-1500):i+600] if i >= 0 else clean[-1800:])
PY
