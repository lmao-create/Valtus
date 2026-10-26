#!/bin/bash
set -u
W=/root/valtus-inst-test
echo "=== second-boot QEMU stderr ==="
cat "$W/qemu.stderr" 2>/dev/null
echo
echo "=== install transcript (archived) ==="
LATEST=$(ls -dt /mnt/c/Users/hp/Desktop/Custom\ OS/logs/installer-test-* | head -1)
python3 - "$LATEST/serial-live-install.log" <<'PY'
import sys, re
try:
    raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
except FileNotFoundError:
    print("missing"); sys.exit()
clean = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', raw).replace('\r', '')
i = clean.find('calamares -c')
if i >= 0:
    print(clean[i-200:i+2000])
else:
    print(clean[-2000:])
PY
