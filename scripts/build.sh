#!/usr/bin/env bash
# =============================================================================
# Valtus — reproducible ISO build pipeline (part 1: setup, stages 1-2)
# Concatenated with build.part2.sh by the make/scripts flow. See docs/BUILD.md.
# =============================================================================
set -o nounset
set -o errtrace
set -o pipefail
set -e
shopt -s nullglob

# --- Locate project (handles spaces in path) --------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"

# --- Options -----------------------------------------------------------------
FROM_STAGE=1
TO_STAGE=5
CLEAN_BUILD=0
usage() {
  cat <<'EOF'
Usage: build.sh [--from N] [--to N] [--clean]
  --from N   start at stage N (default 1), reusing earlier cached stages
  --to N     stop after stage N (default 5)
  --clean    wipe the WSL build workspace first (keeps releases/)
EOF
}
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM_STAGE="$2"; shift 2 ;;
    --to) TO_STAGE="$2"; shift 2 ;;
    --clean) CLEAN_BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# --- Logging -----------------------------------------------------------------
TS="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/build-$TS.log"

log() { echo "[build $(date +%H:%M:%S)] $*"; }
die() { log "FATAL: $*"; log "FAILED during stage ${CURRENT_STAGE:-?}"; exit 1; }
trap 'log "FAILED during stage ${CURRENT_STAGE:-?} (line ${BASH_LINENO:-?})"' ERR INT TERM
trap 'umount_chroot >/dev/null 2>&1 || true' EXIT
stage_fail() { log "FAILED during stage ${CURRENT_STAGE:-?} (line ${BASH_LINENO[0]:-?})"; }

if [ "$(id -u)" -ne 0 ]; then
  echo "This build must run as root inside WSL:" >&2
  echo "  wsl -d Debian -u root -- bash '$0'" >&2
  exit 1
fi

# --- Tool check --------------------------------------------------------------
missing=()
for tool in debootstrap mksquashfs xorriso grub-mkrescue mformat zstd tar rsync rsvg-convert wget awk grep sed; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing build tools: ${missing[*]}" >&2
  echo "Install (Debian WSL): apt-get install debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin grub-common mtools zstd rsync librsvg2-bin wget" >&2
  exit 1
fi

# --- Configuration -----------------------------------------------------------
. "$PROJECT_DIR/config/distro.conf"
. "$PROJECT_DIR/config/valtus.env"          # credentials/sensitive defaults
if [ -f "$PROJECT_DIR/config/valtus.local.env" ]; then
  . "$PROJECT_DIR/config/valtus.local.env"  # gitignored local overrides
fi
: "${DISTRO_ID:?distro.conf not loaded}"
: "${LIVE_USER:?valtus.env not loaded}"
: "${LIVE_USER_PASSWORD:?valtus.env not loaded}"

BUILD_DIR="${VALTUS_BUILD_DIR:-$HOME/valtus-build}"
WORK="$BUILD_DIR/work"
ROOTFS="$WORK/rootfs"
ISODIR="$WORK/iso"
CACHE="$BUILD_DIR/cache"
OUTDIR="$BUILD_DIR/out"
OVERLAY="$PROJECT_DIR/config/rootfs"
RELEASES="$PROJECT_DIR/releases"
ISO_NAME="${DISTRO_ID,,}-${DISTRO_VERSION}-${DISTRO_ARCH}.iso"
ISO_OUT="$OUTDIR/$ISO_NAME"

export BASE_MIRROR DISTRO_LOCALE DISTRO_TIMEZONE

read_packages() { # $1 = package list file
  grep -Ev '^[[:space:]]*(#|$)' "$1" | tr '\n' ' '
}
PKGS_BASE="$(read_packages "$PROJECT_DIR/config/packages/base.txt")"
PKGS_DESKTOP="$(read_packages "$PROJECT_DIR/config/packages/desktop.txt")"
PKGS_SECURITY="$(read_packages "$PROJECT_DIR/config/packages/security.txt")"

mkdir -p "$WORK" "$CACHE" "$OUTDIR" "$RELEASES" "$BUILD_DIR"

if [ "$CLEAN_BUILD" -eq 1 ]; then
  log "cleaning WSL build workspace $BUILD_DIR (releases/ untouched)"
  rm -rf "$WORK" "$CACHE"
fi

# Redirect all output to the log file as well
exec > >(tee -a "$LOG_FILE") 2>&1
log "Valtus build $TS"
log "identity: $DISTRO_NAME $DISTRO_VERSION ('$DISTRO_CODENAME') on $BASE_DISTRO/$BASE_DISTRO_VERSION $DISTRO_ARCH"
log "build dir: $BUILD_DIR"

# --- Stage helpers -------------------------------------------------------------
CURRENT_STAGE="preflight"
stage() { # $1 = stage number, $2 = name
  local n="$1" name="$2"
  CURRENT_STAGE="$n:$name"
  if [ "$n" -lt "$FROM_STAGE" ] || [ "$n" -gt "$TO_STAGE" ]; then return 1; fi
  log "=== STAGE $n: $name ==="
  return 0
}

snapshot_save() { # $1 = tarball name
  log "saving snapshot $1"
  ( cd "$ROOTFS" && tar --numeric-owner -cf - . ) | zstd -T2 -3 -q > "$CACHE/$1"
  [ -s "$CACHE/$1" ] || die "snapshot $1 empty"
}
snapshot_restore() { # $1 = tarball name
  [ -f "$CACHE/$1" ] || die "snapshot $1 missing; run from an earlier stage"
  log "restoring snapshot $1"
  rm -rf "$ROOTFS"
  mkdir -p "$ROOTFS"
  zstd -dc "$CACHE/$1" | tar -C "$ROOTFS" -xf -
}
marker() { [ -f "$CACHE/$1.done" ]; }
mark() { : > "$CACHE/$1.done"; }

prepare_rootfs_from() { # $1 = snapshot name
  if [ -d "$ROOTFS" ] && [ -f "$ROOTFS/etc/hostname" ]; then return 0; fi
  snapshot_restore "$1"
}

mount_chroot() {
  if [ "$(findmnt -n -o TARGET "$ROOTFS/proc" 2>/dev/null)" != "$ROOTFS/proc" ]; then
    mount --bind /proc "$ROOTFS/proc"
  fi
  if [ "$(findmnt -n -o TARGET "$ROOTFS/sys" 2>/dev/null)" != "$ROOTFS/sys" ]; then
    mount --bind /sys "$ROOTFS/sys"
  fi
  if [ "$(findmnt -n -o TARGET "$ROOTFS/dev" 2>/dev/null)" != "$ROOTFS/dev" ]; then
    mount --bind /dev "$ROOTFS/dev"
  fi
}
umount_chroot() {
  for d in proc sys dev; do
    if [ "$(findmnt -n -o TARGET "$ROOTFS/$d" 2>/dev/null)" = "$ROOTFS/$d" ]; then
      umount "$ROOTFS/$d" || log "warning: could not umount $ROOTFS/$d"
    fi
  done
}
run_chroot() {
  chroot "$ROOTFS" /usr/bin/env -i \
    DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HOME=/root "$@"
}

# === STAGE 1: bootstrap ======================================================
if stage 1 bootstrap; then
  if ! marker 01; then
    rm -rf "$ROOTFS"
    log "debootstrap $BASE_DISTRO -> $ROOTFS"
    debootstrap --variant=minbase --arch="$DISTRO_ARCH" \
      --include=ca-certificates,sudo,locales \
      --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg \
      "$BASE_DISTRO" "$ROOTFS" "$BASE_MIRROR" \
      || die "debootstrap failed"
    mark 01
  else
    prepare_rootfs_from 01-bootstrap.tar.zst
  fi
  snapshot_save 01-bootstrap.tar.zst
fi

# === STAGE 2: packages =======================================================
if stage 2 packages; then
  if ! marker 02; then
    prepare_rootfs_from 01-bootstrap.tar.zst
    log "installing package sets into rootfs"
    mount_chroot
    mkdir -p "$ROOTFS/etc/apt"
    cp "$OVERLAY/etc/apt/sources.list" "$ROOTFS/etc/apt/sources.list"
    cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf" 2>/dev/null || true
    printf '#!/bin/sh\nexit 101\n' > "$ROOTFS/usr/sbin/policy-rc.d"
    chmod +x "$ROOTFS/usr/sbin/policy-rc.d"

    run_chroot apt-get -qq update || die "apt update in chroot failed"
    log "installing: $PKGS_BASE"
    run_chroot apt-get install -y --no-remove $PKGS_BASE \
      || die "base package install failed"
    log "installing: $PKGS_DESKTOP"
    run_chroot apt-get install -y --no-remove $PKGS_DESKTOP \
      || die "desktop package install failed"
    log "installing: $PKGS_SECURITY"
    run_chroot apt-get install -y --no-remove $PKGS_SECURITY \
      || die "security package install failed"

    run_chroot locale-gen "$DISTRO_LOCALE" || die "locale-gen failed"
    printf 'LANG=%s\n' "$DISTRO_LOCALE" > "$ROOTFS/etc/default/locale"
    ln -sf "/usr/share/zoneinfo/$DISTRO_TIMEZONE" "$ROOTFS/etc/localtime"
    printf '%s\n' "$DISTRO_TIMEZONE" > "$ROOTFS/etc/timezone"
    run_chroot bash -c "echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections && \
      echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections && \
      dpkg-reconfigure -f noninteractive tzdata" || log "warn: tzdata reconfigure"

    run_chroot apt-get clean
    rm -rf "$ROOTFS/var/lib/apt/lists"/*
    umount_chroot
    mark 02
  else
    prepare_rootfs_from 02-packages.tar.zst
  fi
  snapshot_save 02-packages.tar.zst
fi

# === STAGE 3: customize ======================================================
if stage 3 customize; then
  if ! marker 03; then
    prepare_rootfs_from 02-packages.tar.zst
    log "applying Valtus configuration overlay and branding"

    # 1) System overlay
    log "rsync overlay"
    rsync -a "$OVERLAY/" "$ROOTFS/"
    # Ensure standard overlay file permissions
    find "$ROOTFS/etc/casper.conf" "$ROOTFS/etc/hostname" "$ROOTFS/etc/hosts" \
         "$ROOTFS/etc/motd" "$ROOTFS/etc/issue" "$ROOTFS/etc/timezone" \
         "$ROOTFS/etc/sysctl.d" "$ROOTFS/etc/sddm.conf.d" \
         "$ROOTFS/etc/security" "$ROOTFS/etc/apt" "$ROOTFS/etc/default" \
         -type f -exec chmod 644 {} + 2>/dev/null || true

    # 2) Identity files (generated from config/distro.conf)
    log "writing os-release / lsb-release for $DISTRO_NAME"
    mkdir -p "$ROOTFS/etc"
    printf '%s\n' \
"NAME=\"$DISTRO_NAME\"" \
"ID=ubuntu" \
"ID_LIKE=debian" \
"PRETTY_NAME=\"$DISTRO_NAME $DISTRO_VERSION '$DISTRO_CODENAME'\"" \
"VERSION=\"$DISTRO_VERSION ($DISTRO_CODENAME)\"" \
"VERSION_ID=\"$DISTRO_VERSION\"" \
"VERSION_CODENAME=$BASE_DISTRO" \
"UBUNTU_CODENAME=$BASE_DISTRO" \
"HOME_URL=\"https://valtus.invalid/\"" \
"SUPPORT_URL=\"https://valtus.invalid/support\"" \
"BUG_REPORT_URL=\"https://valtus.invalid/bugs\"" \
"BUILD_ID=\"$DISTRO_ID-$DISTRO_VERSION-$TS\"" \
"LOGO=${DISTRO_ID}" \
> "$ROOTFS/etc/os-release"
    # /usr/lib/os-release is a usrmerge symlink to /etc/os-release on noble,
    # so writing /etc/os-release alone is authoritative.
    printf '%s\n' \
"DISTRIB_ID=$DISTRO_NAME" \
"DISTRIB_RELEASE=$DISTRO_VERSION" \
"DISTRIB_CODENAME=$DISTRO_CODENAME" \
"DISTRIB_DESCRIPTION=\"$DISTRO_DESCRIPTION ($BASE_DISTRO_VERSION)\"" \
> "$ROOTFS/etc/lsb-release"

    # 3) Branding assets (rendered from editable SVG sources)
    log "rendering branding assets to PNG"
    WALL="$ROOTFS/usr/share/wallpapers/valtus"
    mkdir -p "$WALL/contents/images" "$ROOTFS/usr/share/valtus" \
             "$ROOTFS/usr/share/color-schemes" \
             "$ROOTFS/usr/share/plasma/look-and-feel/org.valtus.desktop/contents" \
             "$ROOTFS/usr/share/applications"
    cp "$PROJECT_DIR/config/desktop/wallpaper/metadata.json" "$WALL/metadata.json"
    rsvg-convert -w 1920 -h 1080 "$PROJECT_DIR/$DISTRO_WALLPAPER_SVG" \
        -o "$WALL/contents/images/1920x1080.png" || die "wallpaper 1080p render failed"
    rsvg-convert -w 3840 -h 2160 "$PROJECT_DIR/$DISTRO_WALLPAPER_SVG" \
        -o "$WALL/contents/images/3840x2160.png" || die "wallpaper 2160p render failed"
    rsvg-convert -w 256 -h 256 "$PROJECT_DIR/$DISTRO_LOGO_SVG" \
        -o "$ROOTFS/usr/share/valtus/logo.png" || die "logo render failed"
    rsvg-convert -w 128 -h 128 "$PROJECT_DIR/branding/logos/valtus-emblem.svg" \
        -o "$ROOTFS/usr/share/valtus/emblem.png" || die "emblem render failed"
    cp "$PROJECT_DIR/$DISTRO_LOGO_SVG" "$ROOTFS/usr/share/valtus/logo.svg"
    cp "$PROJECT_DIR/branding/logos/valtus-emblem.svg" "$ROOTFS/usr/share/valtus/emblem.svg"
    cp "$PROJECT_DIR/branding/themes/$DISTRO_THEME.colors" \
       "$ROOTFS/usr/share/color-schemes/$DISTRO_THEME.colors"
    cp "$PROJECT_DIR/config/desktop/look-and-feel/metadata.json" \
       "$ROOTFS/usr/share/plasma/look-and-feel/org.valtus.desktop/metadata.json"
    cp "$PROJECT_DIR/config/desktop/look-and-feel/defaults" \
       "$ROOTFS/usr/share/plasma/look-and-feel/org.valtus.desktop/contents/defaults"
    install -m 0755 "$PROJECT_DIR/scripts/valtus-welcome.py" "$ROOTFS/usr/bin/valtus-welcome"
    install -m 0644 "$PROJECT_DIR/config/desktop/applications/valtus-welcome.desktop" \
        "$ROOTFS/usr/share/applications/valtus-welcome.desktop"

    # 4) Desktop defaults for every user (/etc/skel)
    log "installing /etc/skel desktop defaults"
    rsync -a "$PROJECT_DIR/config/desktop/skel/" "$ROOTFS/etc/skel/"
    find "$ROOTFS/etc/skel" -type f -exec chmod 644 {} + 2>/dev/null || true

    # 5) Normalize ownership/permissions of Valtus-added paths. Sources on the
    #    /mnt/c project drive carry uid 1000 and mode 777 (DrvFs defaults), and
    #    rsync/cp as root would otherwise ship world-writable, wrongly-owned
    #    system files into the image (defect found and fixed in build #1).
    #    (the credentials hook path is also assigned in step 6 — same value)
    HOOK="$ROOTFS/usr/share/initramfs-tools/scripts/casper-bottom/27valtus-credentials"
    LIVE_CREDS="$ROOTFS/usr/lib/valtus/live-credentials"
    CREDS_UNIT="$ROOTFS/etc/systemd/system/valtus-live-credentials.service"
    VALTUS_PATHS="$ROOTFS/etc $ROOTFS/usr/share/valtus $ROOTFS/usr/share/wallpapers
                  $ROOTFS/usr/share/color-schemes $ROOTFS/usr/share/plasma/look-and-feel
                  $ROOTFS/usr/lib/valtus $ROOTFS/usr/bin/valtus-welcome $CREDS_UNIT"
    log "normalizing ownership and permissions"
    chown -R root:root $VALTUS_PATHS
    find $VALTUS_PATHS -type d -exec chmod 0755 {} + 2>/dev/null || true
    find $VALTUS_PATHS -type f -exec chmod 0644 {} + 2>/dev/null || true
    chmod 0755 "$ROOTFS/usr/bin/valtus-welcome" "$LIVE_CREDS" "$HOOK" 2>/dev/null || true
    chmod 0644 "$CREDS_UNIT" 2>/dev/null || true
    # The rootfs root directory itself inherited DrvFs mode 777 and uid 1000
    chown root:root "$ROOTFS"
    chmod 0755 "$ROOTFS"
    # Special cases from the base system
    for f in shadow gshadow; do
      if [ -f "$ROOTFS/etc/$f" ]; then chown root:shadow "$ROOTFS/etc/$f"; chmod 0640 "$ROOTFS/etc/$f"; fi
    done

    # 6) Live-session credentials — initramfs hook (best effort, runs after
    #    casper's own 25adduser/15autologin; casper 1.498 in noble)
    log "generating casper credentials hook"
    mkdir -p "$(dirname "$HOOK")"
    cat > "$HOOK" <<CREDEOF
#!/bin/sh
# Generated by Valtus build.sh from config/valtus.env - DO NOT edit by hand.
PREREQ="25adduser 15autologin"
prereqs() { echo "\$PREREQ"; }
. /scripts/casper-functions 2>/dev/null || true
. /etc/casper.conf 2>/dev/null || true
: \${USERNAME:=$LIVE_USER}
case "\$1" in
prereqs) prereqs; exit 0 ;;
esac
log_begin_msg "valtus: provisioning live session credentials" 2>/dev/null || \\
  echo "valtus: credentials" > /dev/kmsg
# In the initramfs phase the live root is mounted at /root — every path below
# is under /root (writing to /etc/... here hit the initramfs's own /etc).
mkdir -p /root/etc/sddm.conf.d 2>/dev/null || true
if [ -x /root/usr/sbin/chpasswd ]; then
  echo "$LIVE_USER:$LIVE_USER_PASSWORD" | chroot /root /usr/sbin/chpasswd 2>/dev/null || \\
    echo "valtus: chpasswd (chroot) failed" > /dev/kmsg
fi
rm -f /root/etc/sudoers.d/casper 2>/dev/null || true
cat > /root/etc/sddm.conf.d/zz-valtus-no-autologin.conf <<'EOF'
[Autologin]
User=
Session=
EOF
if [ -f /root/etc/sddm.conf ]; then
  awk '/^\[Autologin\]/ { s = 1 }
       s && /^\[/ && !/^\[Autologin\]/ { s = 0 }
       !s || (/^\[/ && !/^\[Autologin\]/)' /root/etc/sddm.conf > /root/etc/sddm.conf.new 2>/dev/null
  [ -s /root/etc/sddm.conf.new ] && mv /root/etc/sddm.conf.new /root/etc/sddm.conf 2>/dev/null || rm -f /root/etc/sddm.conf.new 2>/dev/null
fi
log_end_msg 2>/dev/null || true
exit 0
CREDEOF
    chmod 755 "$HOOK"

    # 7) Authoritative live-credentials service (runs inside the live system
    #    before sddm). NOTE: systemd ConditionUser= evaluates FALSE in the
    #    live-boot namespace even though the casper-created user exists (it
    #    silently skipped this unit), so the gating happens in the script.
    log "installing valtus-live-credentials systemd service"
    mkdir -p "$(dirname "$LIVE_CREDS")"
    cat > "$LIVE_CREDS" <<CREDEOF2
#!/bin/sh
# Generated by Valtus build.sh from config/valtus.env - DO NOT edit by hand.
set -u
USER_NAME="$LIVE_USER"
log() { logger -t valtus-live-credentials "\$*" 2>/dev/null || echo "valtus: \$*" >&2; }
# Live-session gate: the live system's root IS casper's overlay union
# (installed systems boot ext4). /cow exists only in the initramfs, NOT in
# the running live system — that mistake skipped this unit in build #5.
ROOT_FS=\$(findmnt -n -o FSTYPE / 2>/dev/null || echo unknown)
if [ "\$ROOT_FS" != "overlay" ] && [ ! -d /cdrom ]; then
  log "not a live session (root fs: \$ROOT_FS); nothing to do"
  exit 0
fi
if ! id "\$USER_NAME" >/dev/null 2>&1; then
  log "user \$USER_NAME not present; nothing to do"
  exit 0
fi
log "provisioning live credentials for \$USER_NAME"
echo "$LIVE_USER:$LIVE_USER_PASSWORD" | chpasswd || log "chpasswd failed"
# Desktop group membership for DRM/GL devices
usermod -aG video,render "\$USER_NAME" 2>/dev/null || true
rm -f /etc/sudoers.d/casper
mkdir -p /etc/sddm.conf.d

# Automated-test boot (GRUB entry "live (automated test)"): keep casper
# autologin so the VM harness can capture the desktop without typing, and
# force software GL (headless QEMU hosts have no GL context; VirtualBox and
# real hardware provide their own). Shipped images never take this branch.
if grep -q "valtus.test_autologin=1" /proc/cmdline 2>/dev/null; then
  log "test boot: autologin + software GL override"
  mkdir -p "/home/\$USER_NAME/.config/plasma-workspace/env"
  cat > "/home/\$USER_NAME/.config/plasma-workspace/env/99-valtus-test-gl.sh" <<'EOF'
#!/bin/sh
# Test-boot only: software GL for headless QEMU captures (no virgl on host).
export LIBGL_ALWAYS_SOFTWARE=1
EOF
  chown -R "\$USER_NAME:\$USER_NAME" "/home/\$USER_NAME/.config" 2>/dev/null || true
  exit 0
fi

cat > /etc/sddm.conf.d/zz-valtus-no-autologin.conf <<'EOF'
[Autologin]
User=
Session=
EOF
if [ -f /etc/sddm.conf ]; then
  awk '/^\[Autologin\]/ { s = 1 }
       s && /^\[/ && !/^\[Autologin\]/ { s = 0 }
       !s' /etc/sddm.conf > /etc/sddm.conf.new && mv /etc/sddm.conf.new /etc/sddm.conf
fi
log "done"
exit 0
CREDEOF2
    chmod 755 "$LIVE_CREDS"
    cat > "$CREDS_UNIT" <<EOF
[Unit]
Description=Valtus live session credentials
DefaultDependencies=no
After=local-fs.target
Before=sddm.service display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/lib/valtus/live-credentials
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF
    chmod 644 "$CREDS_UNIT"

    # 8) Security + system configuration inside the chroot
    log "applying hardening in chroot"
    mount_chroot
    run_chroot passwd -l root || log "warn: passwd -l root"
    run_chroot ufw default deny incoming || die "ufw default incoming failed"
    run_chroot ufw default allow outgoing || die "ufw default outgoing failed"
    run_chroot ufw --force enable || die "ufw enable failed"
    run_chroot systemctl enable ufw.service || log "warn: enable ufw.service"
    run_chroot systemctl enable unattended-upgrades.service || log "warn: enable unattended-upgrades.service"
    run_chroot systemctl enable apparmor.service 2>/dev/null || log "warn: apparmor.service"
    run_chroot systemctl enable valtus-live-credentials.service || log "warn: enable valtus-live-credentials.service"
    : > "$ROOTFS/etc/machine-id"
    rm -f "$ROOTFS/var/lib/dbus/machine-id"
    run_chroot update-initramfs -u -k all || die "initramfs rebuild failed"
    run_chroot bash -c "dpkg-query -W -f='\${binary:Package}\t\${Version}\n' > /var/cache/valtus-packages.tsv" 2>/dev/null || true
    umount_chroot

    # Remove build-time policy-rc.d (must never ship in the image)
    rm -f "$ROOTFS/usr/sbin/policy-rc.d"

    # 9) NetworkManager: manage all devices (desktop behaviour). The image
    #    inherited netplan-convention 'unmanaged-devices=*,except:wifi...'
    #    from network-manager's conf.d, which leaves Ethernet unmanaged when
    #    no netplan YAML exists (VM test finding: enp0s2 unmanaged).
    log "enabling NetworkManager for all devices"
    rm -f "$ROOTFS/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf"
    mkdir -p "$ROOTFS/etc/NetworkManager/conf.d"
    cat > "$ROOTFS/etc/NetworkManager/conf.d/10-valtus-defaults.conf" <<'NMEOF'
[main]
plugins=keyfile
NMEOF

    mark 03
  else
    prepare_rootfs_from 03-customized.tar.zst
  fi
  snapshot_save 03-customized.tar.zst
fi

# === STAGE 4: image ==========================================================
if stage 4 image; then
  if ! marker 04; then
    prepare_rootfs_from 03-customized.tar.zst
    log "assembling ISO tree"

    KVER="$(ls -v "$ROOTFS"/boot/vmlinuz-* | tail -1 | sed 's|^.*/vmlinuz-||')"
    [ -n "$KVER" ] || die "no kernel found in $ROOTFS/boot"
    log "kernel: $KVER"

    rm -rf "$ISODIR"; mkdir -p "$ISODIR/casper" "$ISODIR/boot/grub" "$ISODIR/.disk"
    cp "$ROOTFS/boot/vmlinuz-$KVER" "$ISODIR/casper/vmlinuz"
    cp "$ROOTFS/boot/initrd.img-$KVER" "$ISODIR/casper/initrd"

    log "compressing squashfs (zstd)"
    mksquashfs "$ROOTFS" "$ISODIR/casper/filesystem.squashfs" \
      -noappend -b 1M -comp zstd -Xcompression-level 15 \
      -wildcards -regex -e 'var/lib/apt/lists/.*' \
      || die "mksquashfs failed"
    stat -c %s "$ISODIR/casper/filesystem.squashfs" > "$ISODIR/casper/filesystem.size"

    printf '%s\n' "$DISTRO_NAME $DISTRO_VERSION '$DISTRO_CODENAME' - Release $DISTRO_ARCH ($TS)" \
      > "$ISODIR/.disk/info"

    cat > "$ISODIR/boot/grub/grub.cfg" <<'GRUBEOF'
set default=0
set timeout=5
serial --unit=0 --speed=115200
terminal_input console serial
terminal_output console serial

menuentry "Valtus - live session" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper fsck.mode=skip quiet splash console=tty0 console=ttyS0,115200n8 ---
    initrd /casper/initrd
}
menuentry "Valtus — live session (safe graphics)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper fsck.mode=skip nomodeset console=tty0 console=ttyS0,115200n8 ---
    initrd /casper/initrd
}
menuentry "Valtus — live session (automated test)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper fsck.mode=skip console=tty0 console=ttyS0,115200n8 valtus.test_autologin=1 ---
    initrd /casper/initrd
}
GRUBEOF
    sed -i "s|^menuentry \"Valtus |menuentry \"$DISTRO_NAME $DISTRO_VERSION |" "$ISODIR/boot/grub/grub.cfg"

    log "running grub-mkrescue"
    rm -f "$ISO_OUT"
    grub-mkrescue -o "$ISO_OUT" "$ISODIR" -- -volid "$ISO_VOLUME_LABEL" \
      || die "grub-mkrescue failed"
    [ -f "$ISO_OUT" ] || die "ISO not produced"
    log "ISO: $ISO_OUT ($(stat -c %s "$ISO_OUT") bytes)"
    mark 04
  else
    log "stage 4 already marked"
  fi
fi

# === STAGE 5: finalize =======================================================
if stage 5 finalize; then
  [ -f "$ISO_OUT" ] || die "no ISO to finalize (run without --to)"

  log "finalize: checksum + manifest"
  ( cd "$OUTDIR" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256" )

  ISO_SIZE="$(stat -c %s "$ISO_OUT")"
  if [ "$ISO_SIZE" -gt "$ISO_SIZE_LIMIT_BYTES" ]; then
    die "ISO size $ISO_SIZE exceeds policy limit $ISO_SIZE_LIMIT_BYTES"
  fi

  mkdir -p "$RELEASES"
  # Publish memory-safely (dd small blocks after dropping caches): a plain
  # cp of the 2 GB ISO through the /mnt/c filesystem failed with ENOMEM once.
  # Remove the old artifact first so a truncated copy can never survive.
  rm -f "$RELEASES/$ISO_NAME"
  sync 2>/dev/null || true
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
  dd if="$ISO_OUT" of="$RELEASES/$ISO_NAME" bs=1M status=none
  sync 2>/dev/null || true
  # Verify the published artifact byte-for-byte against the built ISO
  if [ "$(stat -c %s "$ISO_OUT")" != "$(stat -c %s "$RELEASES/$ISO_NAME")" ]; then
    die "published ISO size mismatch: $RELEASES/$ISO_NAME"
  fi
  if [ "$(sha256sum "$ISO_OUT" | awk '{print $1}')" != "$(sha256sum "$RELEASES/$ISO_NAME" | awk '{print $1}')" ]; then
    die "published ISO checksum mismatch: $RELEASES/$ISO_NAME"
  fi
  cp -f "$ISO_OUT.sha256" "$RELEASES/$ISO_NAME.sha256"
  log "published and verified: $RELEASES/$ISO_NAME"

  KVER="$(ls -v "$ROOTFS"/boot/vmlinuz-* 2>/dev/null | tail -1 | sed 's|^.*/vmlinuz-||' || echo unknown)"
  PKG_COUNT="$(chroot "$ROOTFS" dpkg-query -f '.\n' -W 2>/dev/null | wc -l || echo 0)"
  GIT_REV="$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo nogit)"
  {
    echo "Valtus $DISTRO_VERSION ('$DISTRO_CODENAME') release manifest"
    echo "=========================================================="
    echo "Build timestamp : $TS"
    echo "Base            : Ubuntu $BASE_DISTRO_VERSION ($BASE_DISTRO) $DISTRO_ARCH"
    echo "Kernel          : $KVER (linux-image-generic, Ubuntu security kernel)"
    echo "Packages        : $PKG_COUNT"
    echo "ISO             : $RELEASES/$ISO_NAME"
    echo "ISO size        : $ISO_SIZE bytes"
    echo "SHA-256         : $(awk '{print $1}' "$RELEASES/$ISO_NAME.sha256")"
    echo "Git revision    : $GIT_REV"
    echo "Build host      : $(uname -srm), $(nproc) cores"
    echo
    echo "Security features:"
    echo "  - root account locked"
    echo "  - ufw default-deny incoming, enabled at boot"
    echo "  - unattended security upgrades enabled"
    echo "  - AppArmor enabled (Ubuntu default)"
    echo "  - sysctl hardening set (90-valtus-hardening.conf)"
    echo "  - documented fixed live credential only (config/valtus.env)"
  } > "$RELEASES/${DISTRO_ID}-${DISTRO_VERSION}-${DISTRO_ARCH}.manifest.txt"
  cp "$RELEASES/${DISTRO_ID}-${DISTRO_VERSION}-${DISTRO_ARCH}.manifest.txt" "$LOG_FILE.manifest.txt" 2>/dev/null || true

  log "BUILD OK"
  log "release ISO: $RELEASES/$ISO_NAME"
  log "sha256: $(awk '{print $1}' "$RELEASES/$ISO_NAME.sha256")"
  cp "$LOG_FILE" "$RELEASES/${DISTRO_ID}-${DISTRO_VERSION}-${DISTRO_ARCH}.build.log" 2>/dev/null || true
fi

if id linux >/dev/null 2>&1; then
  chown -R linux:linux "$RELEASES" "$LOG_DIR" 2>/dev/null || true
fi
exit 0
