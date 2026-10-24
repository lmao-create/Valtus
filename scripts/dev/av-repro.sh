#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
for d in proc sys dev; do [ "$(findmnt -n -o TARGET "$R/$d" 2>/dev/null)" = "$R/$d" ] || mount --bind "/$d" "$R/$d"; done
mkdir -p "$R/pkgs"
cp /root/valtus-build/av/repo/*.deb "$R/pkgs/"
echo "== install exactly like build.sh (full output) =="
chroot "$R" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root bash -c '
  cd /pkgs
  dpkg -i python3-pyside6-compat_*_all.deb valtus-security_*_all.deb valtus-security-helper_*_all.deb 2>&1
  echo "RC=$?"
'
rm -rf "$R/pkgs"
