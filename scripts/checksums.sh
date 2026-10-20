#!/usr/bin/env bash
# =============================================================================
# Valtus — release checksums (SHA-256)
# =============================================================================
# Usage: checksums.sh <iso>   (or no args: latest ISO in releases/)
# Writes <iso>.sha256 next to the file. Never deletes previous artifacts.
# =============================================================================
set -o nounset -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"

if [ $# -ge 1 ]; then
  ISO="$1"
else
  ISO=$(ls -t "$PROJECT_DIR"/releases/*.iso 2>/dev/null | head -1)
fi
[ -f "$ISO" ] || { echo "no ISO found (pass one as argument)" >&2; exit 1; }

DIR=$(dirname -- "$ISO")
BASE=$(basename -- "$ISO")
cd "$DIR"
sha256sum "$BASE" > "$BASE.sha256"
echo "written: $DIR/$BASE.sha256"
cat "$BASE.sha256"
