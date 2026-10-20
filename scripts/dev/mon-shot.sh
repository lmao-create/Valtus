#!/bin/bash
set -u
W=/root/valtus-vm-test-20261020-121513
OUT=$W/screens/now.ppm
rm -f "$OUT"
( printf 'screendump %s\n' "$OUT"; sleep 3; printf 'info status\n'; sleep 1 ) | socat - "UNIX-CONNECT:$W/monitor.sock" 2>/dev/null | tr -d '\r' | grep -a 'VM status\|screendump' | head -3
ls -la "$OUT" 2>/dev/null && echo "captured"
