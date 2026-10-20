#!/bin/bash
set -u
O=/root/valtus-build/out/valtus-0.1.0-amd64.iso
R="/mnt/c/Users/hp/Desktop/Custom OS/releases"
echo "=== out iso ==="
ls -la "$O"
sha256sum "$O"
echo "=== sidecar (out) ==="
cat /root/valtus-build/out/valtus-0.1.0-amd64.iso.sha256
echo "=== releases dir ==="
ls -la "$R"
echo "=== releases iso (if any) ==="
if [ -f "$R/valtus-0.1.0-amd64.iso" ]; then sha256sum "$R/valtus-0.1.0-amd64.iso"; else echo "RELEASE ISO MISSING"; fi
echo "=== free mem ==="
free -h
