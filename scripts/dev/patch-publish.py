#!/usr/bin/env python3
"""Restore fail-fast (set -e + ERR/EXIT traps) and make the publish step
verify the copied file. Also publish memory-safely (dd 1M after dropping
caches) because a plain cp of a 2GB file through DrvFs failed with ENOMEM
under WSL memory pressure once."""
import sys

path = "/mnt/c/Users/hp/Desktop/Custom OS/scripts/build.sh"
with open(path, encoding="utf-8", newline="") as f:
    src = f.read()

edits = []

# 1) fail-fast + traps (after the pipefail line)
edits.append((
    "set -o pipefail\nshopt -s nullglob\n",
    "set -o pipefail\nset -e\nshopt -s nullglob\n",
))

# 2) publish memory-safely and VERIFY (never declare success without evidence)
edits.append((
    '''  mkdir -p "$RELEASES"
  cp -f "$ISO_OUT" "$RELEASES/$ISO_NAME"
  cp -f "$ISO_OUT.sha256" "$RELEASES/$ISO_NAME.sha256"''',
    '''  mkdir -p "$RELEASES"
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
  log "published and verified: $RELEASES/$ISO_NAME"''',
))

for old, new in edits:
    if src.count(old) != 1:
        print(f"anchor problem ({src.count(old)}): {old[:60]!r}")
        sys.exit(1)
    src = src.replace(old, new)

# 3) error handling: die() must abort the script
edits2 = []
edits2.append((
    'die() { log "FATAL: $*"; stage_fail; exit 1; }',
    'die() { log "FATAL: $*"; log "FAILED during stage ${CURRENT_STAGE:-?}"; exit 1; }\n'
    "trap 'log \"FAILED during stage ${CURRENT_STAGE:-?} (line ${BASH_LINENO:-?})\"' ERR INT TERM\n"
    "trap 'umount_chroot >/dev/null 2>&1 || true' EXIT",
))
for old, new in edits2:
    if src.count(old) != 1:
        print(f"die-anchor problem ({src.count(old)}): {old[:60]!r}")
        sys.exit(1)
    src = src.replace(old, new)

with open(path, "w", encoding="utf-8", newline="") as f:
    f.write(src)
print("build.sh patched: fail-fast + verified publish")
