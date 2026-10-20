#!/bin/bash
set -u
mkdir -p /tmp/initrd-x && cd /tmp/initrd-x && rm -rf *
unmkinitramfs /root/valtus-build/work/iso/casper/initrd . >/dev/null 2>&1
echo "=== layout ==="
ls
echo "=== modules.dep present? ==="
find . -name 'modules.dep*' -o -name 'modules.alias*' | head -5
echo "=== overlay in modules.dep? ==="
grep -h overlay $(find . -name 'modules.dep' | head -2) 2>/dev/null || echo "overlay NOT in modules.dep"
echo "=== modules.builtin mentions overlay? ==="
grep -h overlay $(find . -name 'modules.builtin*' | head -2) 2>/dev/null || echo "overlay not in builtin"
echo "=== check main/early split ==="
ls main 2>/dev/null | head; ls early 2>/dev/null | head
echo "=== size of main ==="
du -sh main 2>/dev/null
