#!/bin/bash
set -u
R=/root/valtus-build/work/rootfs
for d in proc sys dev; do
  [ "$(findmnt -n -o TARGET "$R/$d" 2>/dev/null)" = "$R/$d" ] || mount --bind "/$d" "$R/$d"
done
cp /etc/resolv.conf "$R/etc/resolv.conf"
chroot "$R" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  bash -c 'apt-get -qq update && apt-get install -y --no-install-recommends calamares os-prober libkpmcore12 util-linux-extra && echo CALAMARES-OK' 2>&1 | tail -3
dpkg --root="$R" -l calamares libkpmcore12 2>/dev/null | grep '^ii'
