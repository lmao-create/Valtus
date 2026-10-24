#!/bin/bash
set -u
dpkg-deb -c /root/valtus-av-build/repo/valtus-security_1.0.0_all.deb | grep -E 'libexec|polkit'
