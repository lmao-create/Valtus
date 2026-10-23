#!/bin/bash
set -u
L=$(ls -t /mnt/c/Users/hp/Desktop/Custom\ OS/logs/vm-test-*/serial.log | head -1)
echo "log: $L"
for pat in "grep PRETTY_NAME" "wc -l" "nmcli" "ping -c1" "ufw status" "id -un root" "shadow" "lsm" "apt-get update" "srm" "poweroff"; do
  echo "=== $pat ==="
  grep -a -A3 -- "$pat" "$L" | head -8
  echo
done
echo "=== last 20 lines ==="
tail -20 "$L"
