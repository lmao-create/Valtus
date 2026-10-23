#!/bin/bash
set -u
L=/root/valtus-gui/serial.log
echo "=== tail of serial log ==="
tail -12 "$L"
echo "=== boot markers ==="
grep -a -cE "login:" "$L"
grep -a -iE "sddm|Started.*graphical" "$L" | tail -3
echo "=== qemu still running? ==="
ps aux | grep -c '[q]emu-system'
