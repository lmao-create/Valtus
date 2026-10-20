#!/bin/bash
set -u
W=/root/valtus-vm-test-20261020-121513
echo "=== try connecting a client (stderr visible) ==="
timeout 6 socat - "UNIX-CONNECT:$W/serial.sock" < "$W/cmd.fifo" > /tmp/socat-test.log
echo "socat rc=$?"
echo "--- captured from guest ---"
wc -c /tmp/socat-test.log
tail -c 800 /tmp/socat-test.log | tr -d '\0'
echo
echo "=== socket perms ==="
ls -la "$W/serial.sock"
rm -f /tmp/socat-test.log
