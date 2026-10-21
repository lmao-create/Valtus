#!/bin/bash
set -u
cd /root/valtus-inspect
echo "=== libclamav* packages ==="
zcat Packages.gz Packages-universe.gz | grep "^Package: libclamav" | sort -u
echo "=== clamav package deps/provides ==="
zcat Packages.gz Packages-universe.gz | awk '/^Package: clamav$/{f=1} f&&/^(Version|Depends|Provides):/{print} f&&/^$/{exit}'
