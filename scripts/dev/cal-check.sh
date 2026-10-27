#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "=== /etc/calamares contents ==="
ls -la "$R/etc/calamares/" 2>/dev/null || echo "(no /etc/calamares)"
echo "=== head of settings.conf if present ==="
head -12 "$R/etc/calamares/settings.conf" 2>/dev/null || echo "(no settings.conf — Calamares will use its built-in defaults)"
echo "=== branding ==="
ls "$R/usr/share/calamares/branding/valtus/" 2>/dev/null || echo "(no branding)"
