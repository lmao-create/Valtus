#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "=== /etc/network/interfaces (ifupdown wins over NM) ==="
cat "$R/etc/network/interfaces" 2>/dev/null || echo "(absent)"
echo "=== NetworkManager config ==="
ls -la "$R/etc/NetworkManager/" 2>/dev/null
cat "$R/etc/NetworkManager/NetworkManager.conf" 2>/dev/null || echo "(no NM.conf)"
ls "$R/usr/lib/NetworkManager/conf.d/" 2>/dev/null
cat "$R/usr/lib/NetworkManager/conf.d/"*.conf 2>/dev/null | head -20
echo "=== netplan ==="
ls -la "$R/etc/netplan/" 2>/dev/null || echo "(no netplan)"
echo "=== udev rules mentioning unmanaged ==="
grep -rln "unmanaged" "$R/etc/udev/rules.d/" "$R/usr/lib/udev/rules.d/" 2>/dev/null || echo "(none)"
echo "=== NM installed? ==="
dpkg --root="$R" -l network-manager 2>/dev/null | tail -1
echo "=== ifupdown present? ==="
dpkg --root="$R" -l ifupdown 2>/dev/null | tail -1
echo "=== is enp0s2 lease/address state deterministic? check NM device dir ==="
ls "$R/run/NetworkManager" 2>/dev/null || echo "(runtime dir not in image - expected)"
