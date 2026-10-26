#!/bin/bash
set -u
W=/root/valtus-inst-test
L="$W/serial.log"
echo "log size: $(wc -c < "$L" 2>/dev/null || echo 0)"
echo "=== full log (ANSI stripped) ==="
strings "$L" | grep -avE '^\s*$' | tail -50
