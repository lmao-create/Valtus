#!/bin/bash
set -u
L=$(ls -t /mnt/c/Users/hp/Desktop/Custom\ OS/logs/vm-test-*/serial.log 2>/dev/null | head -1)
echo "log: $L"
echo "=== total lines ==="
wc -l "$L"
echo "=== first 40 lines ==="
head -40 "$L"
echo "=== around the cow failure ==="
grep -n -B8 -A8 'cow format' "$L" | head -40
echo "=== casper/kernel module errors ==="
grep -n -i 'overlay\|modprobe\|CASPER\|begin: \|done.' "$L" | head -30
