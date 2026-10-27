#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "=== /etc/calamares now (settings.conf must be GONE) ==="
ls -la "$R/etc/calamares/" 2>/dev/null
echo "=== branding present ==="
ls "$R/usr/share/calamares/branding/valtus/" 2>/dev/null
echo "=== launcher ==="
ls -la "$R/usr/bin/valtus-install" 2>/dev/null
