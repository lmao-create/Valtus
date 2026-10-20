#!/bin/bash
set -u
echo "=== processes ==="
ps aux | grep -E 'dbg-vm|qemu-system|socat' | grep -v grep | head -5
echo "=== log size / mtime ==="
ls -la --time-style=full-iso /root/valtus-dbg/ 2>/dev/null
echo "=== log last 5 ==="
tail -5 /root/valtus-dbg/serial.log 2>/dev/null
