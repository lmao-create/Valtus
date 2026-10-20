#!/bin/bash
set -u
echo "=== qemu + socat ==="
ps aux | grep -E 'qemu-system|socat' | grep -v grep | head -6
echo "=== work dir ==="
ls -la /root/valtus-vm-test-20261020-121513/ 2>/dev/null || ls -la $(ls -dt /root/valtus-vm-test-* | head -1) 2>/dev/null
echo "=== log ==="
L=$(ls -t /mnt/c/Users/hp/Desktop/Custom\ OS/logs/vm-test-*/serial.log | head -1)
ls -la "$L"
echo "--- tail (raw) ---"
tail -c 2000 "$L" | tr -d '\0' | tail -10
