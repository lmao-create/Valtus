#!/bin/bash
set -u
echo "=== sleep infinity keepers ==="
ps aux | grep 'sleep infinity' | grep -v grep | head -4 || echo "NONE — keeper died"
echo "=== socat of any kind ==="
ps aux | grep socat | grep -v grep || echo "no socat at all"
echo "=== test_vm.sh: serial setup lines ==="
grep -n 'CMDFIFO\|socat\|sleep infinity\|KPID\|RPID' "/mnt/c/Users/hp/Desktop/Custom OS/scripts/test_vm.sh" | head -20
echo "=== the full kill/cleanup trap ==="
sed -n '/^cleanup()/,/^}/p' "/mnt/c/Users/hp/Desktop/Custom OS/scripts/test_vm.sh"
