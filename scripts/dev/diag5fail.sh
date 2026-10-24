#!/bin/bash
set -u
L=$(ls -t /mnt/c/Users/hp/Desktop/Custom\ OS/logs/vm-test-*/serial.log | head -1)
echo "log: $L"
echo "=== 1. systemctl --failed output ==="
grep -a -A3 'systemctl --failed' "$L" | head -6
echo "=== 2. root shadow line ==="
grep -a -B1 -A2 "grep --color=never '\^root:'" "$L" | head -6
grep -a 'root:' "$L" | head -3
echo "=== 3. curl reachability output ==="
grep -a -A3 'curl -sS' "$L" | head -6
echo "=== 4. srm install output ==="
grep -a -A4 'apt-get install -y --no-install-recommends srm' "$L" | head -8
echo "=== 5. poweroff output ==="
grep -a -A4 'systemctl poweroff' "$L" | head -8
tail -4 "$L"
