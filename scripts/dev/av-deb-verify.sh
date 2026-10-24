#!/bin/bash
set -u
MAIN=/root/valtus-av-build/repo/valtus-security_1.0.0_all.deb
HELPER=/root/valtus-av-build/repo/valtus-security-helper_1.0.0_all.deb
echo "main deb libexec/polkit entries (expect 0):"
dpkg-deb -c "$MAIN" | grep -cE 'libexec|polkit' || true
echo "helper deb libexec/polkit entries (expect 2):"
dpkg-deb -c "$HELPER" | grep -cE 'libexec|polkit' || true
echo "overlap check (files in both, expect none):"
comm -12 <(dpkg-deb -c "$MAIN" | awk '{print $6}' | sort -u) \
         <(dpkg-deb -c "$HELPER" | awk '{print $6}' | sort -u) | grep -v '^\./$\|^\./usr/$\|^\./usr/libexec/$\|^\./usr/share/$\|^\./usr/share/polkit-1/$\|^\./usr/share/polkit-1/actions/$' || echo "no file overlap (dirs only)"
