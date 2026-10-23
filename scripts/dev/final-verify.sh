#!/bin/bash
set -u
R="/mnt/c/Users/hp/Desktop/Custom OS/releases"
I="$R/valtus-0.1.0-amd64.iso"
echo "=== size ==="
stat -c '%s bytes (%s)' "$I"
echo "=== sha256 vs sidecar + manifest ==="
S=$(sha256sum "$I" | awk '{print $1}')
echo "actual  : $S"
echo "sidecar : $(cat "$R/valtus-0.1.0-amd64.iso.sha256" | awk '{print $1}')"
echo "manifest: $(grep -i 'SHA-256' "$R/valtus-0.1.0-amd64.manifest.txt" | awk '{print $3}')"
echo "=== releases listing ==="
ls -la "$R"
