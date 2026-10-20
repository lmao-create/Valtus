#!/bin/bash
set -u
C=/root/valtus-inspect/casper-tree
echo "=== search everywhere ==="
grep -rln "cow format" "$C" 2>/dev/null | head -5
grep -rln "no support found" "$C" 2>/dev/null | head -5
echo "=== find the live/cow logic file ==="
ls "$C/usr/share/initramfs-tools/scripts/" 2>/dev/null
ls "$C/usr/share/initramfs-tools/scripts/casper-top/" 2>/dev/null
echo "=== grep overlay handling everywhere ==="
grep -rn "overlay" "$C/usr/share/initramfs-tools/scripts/" 2>/dev/null | grep -iv 'autologin' | head -20
