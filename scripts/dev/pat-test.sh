#!/bin/bash
set -u
L=$(ls -t /mnt/c/Users/hp/Desktop/Custom\ OS/logs/vm-test-*/serial.log | head -1)
OUT=$(sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$L" | tail -400)
echo "=== test ^0\$ ==="
printf '%s' "$OUT" | grep -c '^0$' || echo "no match"
echo "=== test ^200 (space) ==="
printf '%s' "$OUT" | grep -c '^200 ' || echo "no match"
echo "=== what do those lines actually look like ==="
printf '%s' "$OUT" | grep -nE '^(0|200)' | head -5
echo "=== hexdump of the '0' line ==="
printf '%s' "$OUT" | grep -A0 -B0 '^0' | head -1 | od -c | head -3
