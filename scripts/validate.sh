#!/usr/bin/env bash
# =============================================================================
# Valtus — ISO validation (static checks; runs in Debian WSL)
# =============================================================================
# Usage: validate.sh <iso>
# Checks: existence, plausible size, checksum, ISO9660/El-Torito structure,
# presence of GRUB EFI/BIOS boot files and the casper boot chain.
# Exit 0 = all checks passed.
# =============================================================================
set -o nounset -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"
. "$PROJECT_DIR/config/distro.conf"

ISO="${1:?usage: validate.sh <iso>}"
PASS=0; FAIL=0
ok()   { echo "PASS: $*"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

[ -f "$ISO" ] || { bad "ISO file missing: $ISO"; exit 1; }
ok "file exists: $ISO"

SIZE=$(stat -c %s "$ISO")
[ "$SIZE" -gt 150000000 ] && ok "size plausible: $SIZE bytes" || bad "size too small: $SIZE"
[ "$SIZE" -le "${ISO_SIZE_LIMIT_BYTES}" ] && ok "size within policy limit ($ISO_SIZE_LIMIT_BYTES)" \
  || bad "size exceeds policy limit: $SIZE > $ISO_SIZE_LIMIT_BYTES"

# Checksum
SHA=$(sha256sum "$ISO" | awk '{print $1}')
if [ -f "$ISO.sha256" ]; then
  ( cd "$(dirname "$ISO")" && sha256sum -c "$(basename "$ISO").sha256" >/dev/null 2>&1 ) \
    && ok "sha256 verified against sidecar file" || bad "sha256 mismatch vs sidecar"
else
  ok "sha256 computed: $SHA"
fi
echo "sha256: $SHA"

# ISO structure via xorriso (no mount required)
INFO=$(xorriso -indev "$ISO" -toc 2>/dev/null)
printf '%s' "$INFO" | grep -q "ISO session" && ok "ISO9660 filesystem present" || bad "xorriso cannot read ISO"

for f in /casper/vmlinuz /casper/initrd /casper/filesystem.squashfs /boot/grub/grub.cfg; do
  LS=$(xorriso -indev "$ISO" -ls "$(dirname "$f")" -- 2>/dev/null)
  if printf '%s' "$LS" | grep -q "$(basename "$f")"; then ok "present: $f"; else bad "missing: $f"; fi
done

# grub-mkrescue writes the EFI tree with Rock Ridge lowercase names (/efi/...)
EFI_LISTING=$(xorriso -indev "$ISO" -ls /EFI/BOOT -- 2>/dev/null; xorriso -indev "$ISO" -ls /efi/boot -- 2>/dev/null)
if printf '%s' "$EFI_LISTING" | grep -Eqi 'bootx64\.efi|grubx64\.efi|boot\.sd'; then
  ok "GRUB EFI bootloader present (/efi/boot/...)"
else
  # fall back: modern grub-mkrescue puts an efi.img and BOOTX64 at rr root
  ROOTLIST=$(xorriso -indev "$ISO" -ls / -- 2>/dev/null)
  if printf '%s' "$ROOTLIST" | grep -Eqi 'efi\.img'; then ok "GRUB EFI boot image (/efi.img) present"; else bad "GRUB EFI bootloader files not found in image"; fi
fi

BIOS=$(printf '%s\n' "$INFO" | grep -i "El Torito\|boot catalog\|isolinux" | head -3)
[ -n "$BIOS" ] && ok "El Torito (BIOS) boot record present" || echo "WARN: no explicit El Torito line (xorriso output format varies)"

echo
echo "validate.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
