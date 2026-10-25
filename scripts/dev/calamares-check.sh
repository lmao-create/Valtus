#!/bin/bash
set -u
cd /root/valtus-inspect
echo "=== calamares availability ==="
zcat Packages.gz Packages-universe.gz | awk '/^Package: calamares$/{f=1} f&&/^Version:/{print "version:",$2; exit}'
for p in libkpmcore12 os-prober calamares-settings-ubuntu kpmcore; do
  v=$(zcat Packages.gz Packages-universe.gz | awk -v pk="$p" '$0=="Package: "pk{f=1;next} f&&/^Version:/{print $2; exit}')
  [ -n "$v" ] && echo "AVAIL   $p = $v" || echo "MISSING $p"
done
echo "=== kpmcore soname in noble ==="
zcat Packages.gz Packages-universe.gz | grep -E '^Package: libkpmcore' | head -3
echo "=== calamares deps (Depends) ==="
zcat Packages.gz Packages-universe.gz | awk '/^Package: calamares$/{f=1} f&&/^Depends:/{print; exit}'
