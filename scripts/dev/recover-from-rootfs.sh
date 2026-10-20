#!/bin/bash
# Recover the Valtus project source files from the built rootfs after the
# project directory was lost. The rootfs carries the exact built state of
# every config, branding asset and installed script.
set -u
P="/mnt/c/Users/hp/Desktop/Custom OS"
R="/root/valtus-build/work/rootfs"

mkdir -p "$P/releases" "$P/config/rootfs/etc/sysctl.d" "$P/config/rootfs/etc/sddm.conf.d" \
         "$P/config/rootfs/etc/security/pwquality.conf.d" "$P/config/rootfs/etc/apt/apt.conf.d" \
         "$P/config/rootfs/etc/default" \
         "$P/config/desktop/skel" "$P/config/desktop/applications" \
         "$P/config/desktop/look-and-feel" "$P/config/desktop/wallpaper" \
         "$P/config/packages" "$P/branding/logos" "$P/branding/wallpapers" "$P/branding/themes" \
         "$P/scripts" "$P/tests" "$P/docs" "$P/logs"

echo "== 1) release artifacts =="
cp /root/valtus-build/out/valtus-0.1.0-amd64.iso "$P/releases/"
cp /root/valtus-build/out/valtus-0.1.0-amd64.iso.sha256 "$P/releases/"

echo "== 2) branding assets =="
cp "$R/usr/share/valtus/logo.svg"   "$P/branding/logos/valtus-logo.svg"
cp "$R/usr/share/valtus/emblem.svg" "$P/branding/logos/valtus-emblem.svg"
cp "$R/usr/share/valtus/logo.png"   "$P/branding/logos/valtus-logo.png"
cp "$R/usr/share/valtus/emblem.png" "$P/branding/logos/valtus-emblem.png"
cp "$R/usr/share/wallpapers/valtus/contents/images/1920x1080.png"  "$P/branding/wallpapers/valtus-wallpaper-1920x1080.png"
cp "$R/usr/share/wallpapers/valtus/contents/images/3840x2160.png"  "$P/branding/wallpapers/valtus-wallpaper-3840x2160.png"
cp "$R/usr/share/color-schemes/ValtusDark.colors" "$P/branding/themes/"
cp "$R/usr/share/wallpapers/valtus/metadata.json" "$P/config/desktop/wallpaper/metadata.json"
cp "$R/usr/share/plasma/look-and-feel/org.valtus.desktop/metadata.json" "$P/config/desktop/look-and-feel/metadata.json"
cp "$R/usr/share/plasma/look-and-feel/org.valtus.desktop/contents/defaults" "$P/config/desktop/look-and-feel/defaults"

echo "== 3) welcome app + desktop entry =="
cp "$R/usr/bin/valtus-welcome" "$P/scripts/valtus-welcome.py"
cp "$R/usr/share/applications/valtus-welcome.desktop" "$P/config/desktop/applications/valtus-welcome.desktop"
cp "$R/etc/systemd/system/valtus-live-credentials.service" "$P/scripts/valtus-live-credentials.service.reference"
cp "$R/usr/share/initramfs-tools/scripts/casper-bottom/27valtus-credentials" "$P/scripts/27valtus-credentials.reference" 2>/dev/null || true

echo "== 4) skel desktop defaults =="
rsync -a "$R/etc/skel/" "$P/config/desktop/skel/"

echo "== 5) rootfs overlay =="
for f in casper.conf hostname hosts motd issue timezone; do
  cp "$R/etc/$f" "$P/config/rootfs/$f"
done
cp "$R/etc/sysctl.d/90-valtus-hardening.conf" "$P/config/rootfs/etc/sysctl.d/"
cp "$R/etc/sddm.conf.d/valtus.conf" "$P/config/rootfs/etc/sddm.conf.d/"
cp "$R/etc/security/pwquality.conf.d/90-valtus.conf" "$P/config/rootfs/etc/security/pwquality.conf.d/"
cp "$R/etc/apt/sources.list" "$P/config/rootfs/etc/apt/"
cp "$R/etc/apt/apt.conf.d/20auto-upgrades" "$P/config/rootfs/etc/apt/apt.conf.d/"
cp "$R/etc/default/locale"  "$P/config/rootfs/etc/default/"
cp "$R/etc/default/keyboard" "$P/config/rootfs/etc/default/"

echo "== 6) reference: generated os-release/iss metadata =="
cp "$R/etc/os-release" "$P/logs/os-release.built.txt"
cp "$R/etc/lsb-release" "$P/logs/lsb-release.built.txt"

echo "RECOVERY COMPLETE"
find "$P" -type f | wc -l
chown -R linux:linux "$P" 2>/dev/null || true
