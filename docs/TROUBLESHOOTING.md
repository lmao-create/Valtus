# Troubleshooting

## Build problems

| Symptom | Cause | Fix |
|---|---|---|
| `This build must run as root inside WSL` | not root | run via `wsl -d Debian -u root -- bash scripts/build.sh` |
| `Missing build tools: ...` | dependencies missing | `make deps` (or the apt list in docs/BUILD.md §1.1) |
| `debootstrap failed` / archive unreachable | network / mirror down | check `getent hosts archive.ubuntu.com`, retry; set `BASE_MIRROR` in `config/distro.conf` for a closer mirror |
| `apt-get install ... failed` in chroot | package name wrong for the release | verify against the noble Packages index; fix `config/packages/*.txt` |
| stage re-run starts over | cache marker missing | expected first run; use `--from <stage>` after a successful stage |
| `mksquashfs failed: no space left` | WSL disk full | `df -h ~`; `make clean-build` |
| `grub-mkrescue failed` | grub binaries/mtools missing | install `grub-pc-bin grub-efi-amd64-bin grub-common mtools` |
| PowerShell `The token '&&' is not...` | PowerShell is not bash | use `;` separators, or run inside `wsl ... -- bash -c '...'` |
| `No such file or directory` on `/mnt/c/.../Custom` | space in path lost through quoting | single-quote the whole command: `wsl ... -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/build.sh'` |

## Boot / VM problems

| Symptom | Likely cause | Fix |
|---|---|---|
| Blank screen after GRUB | graphics mode | pick "safe graphics" (nomodeset) GRUB entry |
| QEMU exits instantly | `-enable-kvm` without `/dev/kvm`, or broken ISO | `ls /dev/kvm`; run without `-enable-kvm` (slow) to isolate |
| No `login:` on serial | console not wired | GRUB entries pass `console=ttyS0,115200n8`; use the harness |
| Login fails with documented password | credentials unit failed | on serial login check `journalctl -u valtus-live-credentials`; rebuild `--from 3` |
| Desktop session missing | sddm/plasma failure | `systemctl status sddm`; `plasmashell --replace` |
| `KWallet: ... has not been initialized` | first-login wallet prompt | create wallet deliberately (INSTALLATION.md §5); avoid empty password |
| No network in VM | virtio driver/NM issue | `ip -br a`, `nmcli device wifi list`, `systemctl status NetworkManager` |
| apt slow/fails in guest | DNS/NAT | `getent hosts archive.ubuntu.com`; QEMU user net provides DNS at 10.0.2.3 |

## VirtualBox notes

- Graphics controller **VMSVGA** (VBoxSVGA gives a black screen with KWin).
- 2 GB RAM minimum, 4 GB recommended; enable EFI for the UEFI path.
- User/password for the live session: `valtus` / `valtus`.

## Desktop appearance

| Task | How |
|---|---|
| Use the ValtusDark color scheme | System Settings → Colors & Themes → ValtusDark (default for new users via `/etc/skel`) |
| Change wallpaper | right-click desktop → Configure Desktop; the Valtus wallpaper ships as a wallpaper package "valtus" |
| Panel layout | the default bottom panel (kickoff + tasks + tray + clock) ships in skel; drag applets freely — changes are per-user |

## Known behaviors, by design

- Live session: unattended-upgrades and update-notifier are disabled by
  casper during live use (`53disable_unattended_upgrades`); installed systems
  keep them enabled.
- `root` account is locked (use `sudo`).
- Autologin is disabled; the login screen is intentional.
