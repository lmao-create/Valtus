#!/bin/bash
set -u
F=/root/valtus-build/work/rootfs/etc/calamares/settings.conf
echo "=== first 6 lines, cat -A (show line ends + tabs) ==="
head -6 "$F" | cat -A | head -8
echo "=== CRLF count ==="
grep -c $'\r' "$F" 2>/dev/null || echo 0
echo "=== tab count ==="
grep -cP '\t' "$F" 2>/dev/null || echo 0
echo "=== python yaml parse ==="
python3 -c "
import yaml
try:
    d = yaml.safe_load(open('$F'))
    print('parsed OK; top-level keys:', list(d.keys()) if isinstance(d, dict) else type(d).__name__)
except Exception as e:
    print('PARSE ERROR:', e)
" 2>/dev/null || echo "(python3-yaml not available)"
