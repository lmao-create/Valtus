#!/bin/bash
set -u
I=/root/valtus-build/work/iso/casper/initrd
echo "=== symlinks / lib layout in initrd ==="
lsinitramfs "$I" 2>/dev/null | grep -E '^(lib|lib/|lib$) ' | head -5
lsinitramfs "$I" 2>/dev/null | grep -E '^l.* lib' | head -5
echo "--- entries literally named lib* ---"
lsinitramfs "$I" 2>/dev/null | awk '$NF=="lib" || $NF=="usr/lib"' | head -5
echo "=== does /lib/modules exist as a path? ==="
lsinitramfs "$I" 2>/dev/null | grep -E '^lib/modules' | head -3 || echo "NO /lib/modules in initrd"
echo "=== is usr/lib/modules the only module location? ==="
lsinitramfs "$I" 2>/dev/null | grep -E 'modules/6\.8' | head -3
echo "=== symlink targets: show symlinks at lib/ ==="
lsinitramfs -l "$I" 2>/dev/null | grep -E 'lib ->' | head -5
echo "=== usr/lib/modules dir entry ==="
lsinitramfs -l "$I" 2>/dev/null | grep -E 'usr/lib/modules' | head -5
