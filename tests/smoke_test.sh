#!/usr/bin/env bash
# =============================================================================
# Valtus — static smoke test suite (no WSL / root / network required)
# =============================================================================
# Verifies the repository's own hygiene: config parseability, absence of
# inline credentials in scripts, line endings, branding assets, permissions.
# Usage: bash tests/smoke_test.sh
# =============================================================================
set -o nounset -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

PASS=0; FAIL=0
ok()  { echo "PASS: $*"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

# --- 1. project structure -----------------------------------------------------
for f in config/distro.conf config/valtus.env scripts/build.sh scripts/validate.sh \
         scripts/checksums.sh scripts/test_vm.sh README.md LICENSE Makefile; do
  [ -f "$f" ] && ok "exists: $f" || bad "missing: $f"
done
for d in docs branding/logos branding/wallpapers branding/themes config/packages \
         config/desktop config/rootfs tests releases logs; do
  [ -d "$d" ] && ok "dir: $d" || bad "missing dir: $d"
done

# --- 2. config files parse and carry required keys ---------------------------
if . config/distro.conf 2>/dev/null; then
  ok "config/distro.conf parses as POSIX shell"
  [ -n "${DISTRO_NAME:-}" ] && ok "DISTRO_NAME present: $DISTRO_NAME" || bad "DISTRO_NAME missing"
  [ -n "${ISO_VOLUME_LABEL:-}" ] && ok "ISO_VOLUME_LABEL: $ISO_VOLUME_LABEL" || bad "ISO_VOLUME_LABEL missing"
  [ -n "${ISO_SIZE_LIMIT_BYTES:-}" ] && ok "ISO_SIZE_LIMIT_BYTES: $ISO_SIZE_LIMIT_BYTES" || bad "ISO_SIZE_LIMIT_BYTES missing"
  printf '%s' "$ISO_VOLUME_LABEL" | grep -Eq '^[A-Z0-9_]{1,32}$' \
    && ok "ISO volume label is ISO9660-safe" || bad "ISO volume label not ISO9660-safe"
else
  bad "config/distro.conf failed to parse"
fi

if . config/valtus.env 2>/dev/null; then
  ok "config/valtus.env parses as POSIX shell"
  [ -n "${LIVE_USER:-}" ] && ok "LIVE_USER present" || bad "LIVE_USER missing"
  [ -n "${LIVE_USER_PASSWORD:-}" ] && ok "LIVE_USER_PASSWORD present (fixed documented credential)" || bad "LIVE_USER_PASSWORD missing"
else
  bad "config/valtus.env failed to parse"
fi

# --- 3. no inline credentials in scripts (env-file pattern) -------------------
# Look for assignment-like lines that embed a literal password. The password
# in config/valtus.env is the env-file pattern and must NOT be elsewhere.
CODE_HITS=$(cat $(find scripts config -name '*.sh' -o -name '*.py' 2>/dev/null) 2>/dev/null \
  | grep -Ev '^[[:space:]]*#' | grep -E '(password|passwd)[[:space:]]*[:=][[:space:]]*"[^"]{3,}"' \
  | grep -v 'LIVE_USER_PASSWORD' | grep -v 'user-password-crypted' || true)
[ -z "$CODE_HITS" ] && ok "no inline credentials in scripts/config" \
  || bad "possible inline credential: $CODE_HITS"

# --- 4. line endings: scripts/config must be LF for WSL ----------------------
CRLF=$(grep -rlU $'\r' --exclude='*.png' --exclude='*.ppm' scripts config tests branding Makefile 2>/dev/null | head -5 || true)
[ -z "$CRLF" ] && ok "no CRLF line endings in text files" || bad "CRLF found in: $CRLF"

# --- 5. package lists ---------------------------------------------------------
for list in base desktop security; do
  f="config/packages/$list.txt"
  n=$(grep -Evc '^[[:space:]]*(#|$)' "$f" 2>/dev/null || echo 0)
  [ "$n" -gt 3 ] && ok "$f: $n packages" || bad "$f: too few packages ($n)"
done

# --- 6. branding assets -------------------------------------------------------
for a in branding/logos/valtus-logo.svg branding/logos/valtus-emblem.svg \
         branding/wallpapers/valtus-wallpaper.svg branding/themes/ValtusDark.colors; do
  [ -s "$a" ] && ok "asset: $a" || bad "missing asset: $a"
done
grep -q '<svg' branding/logos/valtus-logo.svg && ok "logo is valid SVG" || bad "logo SVG malformed"
grep -q 'ColorScheme' branding/themes/ValtusDark.colors && ok "color scheme file looks right" || bad "color scheme malformed"

# --- 6b. rootfs overlay layout (/etc-relative, rsync target) -----------------
for f in etc/casper.conf etc/hostname etc/hosts etc/motd etc/issue \
         etc/timezone etc/sysctl.d/90-valtus-hardening.conf \
         etc/sddm.conf.d/valtus.conf etc/apt/sources.list; do
  [ -f "config/rootfs/$f" ] && ok "overlay: $f" || bad "overlay misplaced/missing: $f"
done

# --- 7. security invariants in the shipped rootfs overlay --------------------
grep -q 'kptr_restrict' config/rootfs/etc/sysctl.d/90-valtus-hardening.conf && ok "sysctl hardening present" || bad "sysctl hardening missing"
grep -q 'minlen' config/rootfs/etc/security/pwquality.conf.d/90-valtus.conf && ok "pwquality policy present" || bad "pwquality missing"
[ "$(grep -c '^deb ' config/rootfs/etc/apt/sources.list)" -eq 4 ] && ok "sources.list: 4 suites" || bad "sources.list malformed"
if grep -rsiq 'openssh-server' config/ 2>/dev/null; then bad "openssh-server present in shipped config (must not be enabled by default)"; else ok "no openssh-server in shipped config"; fi
grep -rsi 'NOPASSWD' config/rootfs config/desktop >/dev/null 2>&1 && bad "NOPASSWD found in shipped config" || ok "no NOPASSWD in shipped config"

# --- 8. VM harness safety guard ----------------------------------------------
grep -q 'valtus-vm-test-\*)' scripts/test_vm.sh && ok "test_vm.sh cleanup has guarded path" || bad "test_vm.sh cleanup guard missing"

echo
echo "smoke_test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
