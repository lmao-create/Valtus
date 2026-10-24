#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
echo "=== packaging tools in the image? ==="
for p in debhelper dh-python python3-setuptools python3-all python3-wheel; do
  st=$(dpkg --root="$R" -l "$p" 2>/dev/null | grep -c '^ii')
  echo "$p: $([ "$st" -ge 1 ] && echo present || echo MISSING)"
done
echo "=== build host has dpkg-buildpackage? ==="
command -v dpkg-buildpackage || echo "MISSING on host"
echo "=== host packaging tools ==="
command -v dh dh_python3 2>/dev/null
dpkg -l debhelper dh-python python3-all 2>/dev/null | grep -c '^ii'
