#!/bin/bash
set -u
W=/root/valtus-vm-test-20261020-121513
OUT="$W/screens/now2.ppm"
rm -f "$OUT"
printf 'screendump %s\n' "$OUT" > /tmp/m1.txt
socat - "UNIX-CONNECT:$W/monitor.sock" < /tmp/m1.txt > /tmp/m1.out 2>/tmp/m1.err
echo "socat rc=$?"
cat /tmp/m1.err
sleep 2
if [ -f "$OUT" ]; then ls -la "$OUT"; else echo "NOT CAPTURED"; fi
ps aux | grep -c '[q]emu-system'
