#!/bin/bash
# Add iputils-ping to the cached stage-2 rootfs so the stage-3+ rebuild picks
# it up without a full 25-minute package reinstall. (base.txt is the source of
# truth for fresh builds; this keeps the incremental iterate equivalent.)
set -u
R=/root/valtus-build/work/rootfs
for d in proc sys dev; do
  [ "$(findmnt -n -o TARGET "$R/$d" 2>/dev/null)" = "$R/$d" ] || mount --bind "/$d" "$R/$d"
done
cp /etc/resolv.conf "$R/etc/resolv.conf"
chroot "$R" /usr/bin/env -i DEBIAN_FRONTEND=noninteractive \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  bash -c 'apt-get -qq update && apt-get install -y --no-install-recommends iputils-ping && command -v ping' || exit 1
dpkg --root="$R" -l iputils-ping | tail -1
