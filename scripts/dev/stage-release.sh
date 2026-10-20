#!/bin/bash
# Stage the complete built ISO at a world-readable WSL path so the Windows
# side can copy it (wsl.localhost access), then verify checksums.
set -u
O=/root/valtus-build/out/valtus-0.1.0-amd64.iso
S=/var/tmp/valtus-release
R="/mnt/c/Users/hp/Desktop/Custom OS/releases"
mkdir -p "$S"
rm -f "$S/valtus-0.1.0-amd64.iso"
# memory-safe copy (dd small blocks) + fsync
dd if="$O" of="$S/valtus-0.1.0-amd64.iso" bs=1M status=none && sync
chmod 755 "$S"
chmod 644 "$S/valtus-0.1.0-amd64.iso"
echo "=== staged ==="
ls -la "$S"
sha256sum "$S/valtus-0.1.0-amd64.iso" "$O"
echo "=== current releases ==="
ls -la "$R"
