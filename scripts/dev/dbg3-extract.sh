#!/bin/bash
set -u
L=$(ls -t /root/valtus-dbg3/serial.log | head -1)
echo "=== UNIT ==="
sed -n '/===UNIT===/,/===JOURNAL===/p' "$L" | head -12
echo "=== JOURNAL ==="
sed -n '/===JOURNAL===/,/===SHADOW===/p' "$L" | head -12
echo "=== SHADOW ==="
sed -n '/===SHADOW===/,/===SDDM-CONF===/p' "$L" | head -6
echo "=== /cow check ==="
grep -a -A2 '/cow' "$L" | head -6
