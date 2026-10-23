#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "=== who owns the globally-managed file? ==="
dpkg --root="$R" -S /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf 2>/dev/null || echo "no package owns it"
echo "=== 85-nm-unmanaged.rules head ==="
head -20 "$R/usr/lib/udev/rules.d/85-nm-unmanaged.rules"
echo "=== does resolv.conf point at resolved? ==="
ls -la "$R/etc/resolv.conf"
echo "=== netplan installed? ==="
dpkg --root="$R" -l netplan.io 2>/dev/null | tail -1
