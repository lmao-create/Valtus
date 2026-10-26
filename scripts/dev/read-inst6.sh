#!/bin/bash
set -u
LATEST=$(ls -dt /mnt/c/Users/hp/Desktop/Custom\ OS/logs/installer-test-* | head -1)
echo "dir: $LATEST"
ls -la "$LATEST" 2>/dev/null
python3 - "$LATEST/serial-live-install.log" <<'PY'
import sys, re
try:
    raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
except FileNotFoundError:
    print("missing"); sys.exit()
clean = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', raw).replace('\r', '')
i = clean.find('unattended.conf')
print(clean[i-400:i+1800] if i >= 0 else clean[-2000:])
PY
