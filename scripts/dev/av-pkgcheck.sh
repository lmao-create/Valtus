#!/bin/bash
set -u
cd /root/valtus-inspect
for p in python3-pyside6 python3-pyside6.qtcore python3-pyside6.qtgui python3-pyside6.qtwidgets python3-psutil clamav clamav-freshclam clamav-daemon libclamav python3-polib dh-python pybuild-plugin-pyproject debhelper; do
  v=$(zcat Packages.gz Packages-universe.gz | grep -A3 "^Package: $p$" | grep -m1 '^Version:' | awk '{print $2}')
  if [ -n "$v" ]; then echo "AVAIL   $p = $v"; else echo "MISSING $p"; fi
done
