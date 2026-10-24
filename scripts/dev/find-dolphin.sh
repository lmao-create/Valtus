#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "=== dolphin binary in image ==="
ls -la "$R/usr/bin/dolphin" "$R/usr/bin/dolphin4" 2>/dev/null
dpkg --root="$R" -L dolphin 2>/dev/null | grep -E '^/usr/bin/' | head -5
echo "=== what provides dolphin on PATH? ==="
ls "$R/usr/bin/" | grep -i dolphin
echo "=== konsole compare ==="
ls -la "$R/usr/bin/konsole" 2>/dev/null
