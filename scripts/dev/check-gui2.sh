#!/bin/bash
set -u
L=/root/valtus-gui/serial.log
echo "=== boot markers ==="
grep -a -nE "Started.*sddm|plasma|kwin|LIBGL|session" "$L" | tail -12
echo "=== line count / tail ==="
wc -l "$L"
tail -6 "$L"
