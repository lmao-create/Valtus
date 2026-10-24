#!/bin/bash
set -u
L=$(ls -t /mnt/c/Users/hp/Desktop/Custom\ OS/logs/vm-test-*/serial.log | head -1)
OUT=$(sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$L")
echo "=== grep '^0$' count ==="
printf '%s' "$OUT" | grep -c '^0$'
echo "=== grep '^200 ' count ==="
printf '%s' "$OUT" | grep -c '^200 '
echo "=== lines starting with 0 or 200 ==="
printf '%s' "$OUT" | grep -nE '^(0$|200 )' | head -5
echo "=== raw bytes near '200 http' ==="
printf '%s' "$OUT" | grep -a '200 http' | head -2 | od -c | head -4
echo "=== raw bytes near systemctl wc output ==="
printf '%s' "$OUT" | grep -a -A1 'systemctl --failed' | head -4 | od -c | head -6
