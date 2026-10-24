#!/bin/bash
# Add the antivirus runtime deps to the cached stage-2 rootfs so the stage-3
# rebuild picks them up (equivalent to what a fresh build's package lists do).
set -u
R=/root/valtus-build/work/rootfs
for d in proc sys dev; do
  [ "$(findmnt -n -o TARGET "$R/$d" 2>/dev/null)" = "$R/$d" ] || mount --bind "/$d" "$R/$d"
done
cp /etc/resolv.conf "$R/etc/resolv.conf"
chroot "$R" /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  bash -c 'apt-get -qq update && apt-get install -y clamav clamav-daemon python3-psutil && echo DEPS-OK' 2>&1 | tail -4
dpkg --root="$R" -l clamav clamav-daemon python3-psutil | grep '^ii'
