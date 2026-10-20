#!/bin/bash
set -u
C=/root/valtus-inspect/casper-tree
echo "=== locate the message ==="
grep -rn "cow format specified" "$C/scripts/" 2>/dev/null | head -3
echo "=== context around it (live script) ==="
F=$(grep -rln "cow format specified" "$C/scripts/" 2>/dev/null | head -1)
echo "file: $F"
grep -n -B30 "cow format specified" "$F" 2>/dev/null | head -60
