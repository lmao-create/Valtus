#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "== installer files in image =="
ls -la "$R/usr/bin/valtus-install" 2>&1
ls "$R/etc/calamares/" 2>/dev/null
ls "$R/usr/share/calamares/branding/valtus/" 2>/dev/null
echo "== calamares binary =="
ls -la "$R/usr/bin/calamares" 2>&1
echo "== desktop entry =="
ls "$R/usr/share/applications/valtus-installer.desktop" 2>&1
echo "== branding content =="
grep -E '^(productName|windowTitle):' "$R/usr/share/calamares/branding/valtus/branding.desc" 2>/dev/null
