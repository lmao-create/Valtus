# Valtus architecture

## 1. Overview

```
┌───────────────────────────────────────────────────────────────┐
│ Valtus 0.1.0 live ISO (BIOS + UEFI hybrid, GRUB)              │
│  /casper/vmlinuz          Linux kernel (Ubuntu HWE-generic)   │
│  /casper/initrd           initramfs incl. casper + Valtus hook│
│  /casper/filesystem.squashfs   the live system root           │
├───────────────────────────────────────────────────────────────┤
│ Ubuntu 24.04 LTS (noble) userspace (apt, systemd, NetworkManager) │
│ KDE Plasma 6 (Wayland default / X11 fallback), SDDM            │
│ Valtus overlay: branding, desktop defaults, hardening, service │
└───────────────────────────────────────────────────────────────┘
```

Build method: **debootstrap + apt + squashfs + grub-mkrescue** — a fully
scripted, reproducible pipeline (`scripts/build.sh`). Cubic was evaluated and
rejected: it is a GUI, interactive, non-reproducible tool and requires an
Ubuntu desktop host, while this environment is Windows + WSL2.

## 2. Build pipeline details

| Stage | Action | Output |
|---|---|---|
| 1 bootstrap | `debootstrap --variant=minbase` noble from `archive.ubuntu.com`, GPG-verified with Ubuntu's official archive keyring | minimal rootfs, cached tarball |
| 2 packages | chroot `apt-get install` of base/desktop/security package sets; kernel + casper; locale; timezone | package rootfs, cached tarball |
| 3 customize | apply `config/rootfs/` overlay; render branding (SVG→PNG); `/etc/skel` desktop defaults; generate credentials hook + systemd unit; lock root; enable ufw/unattended-upgrades/apparmor/credentials unit; rebuild initramfs; normalize ownership/permissions; clean apt lists | customized rootfs, cached tarball |
| 4 image | copy kernel+initrd, `mksquashfs` (zstd), write `.disk/info`, build `grub.cfg`, `grub-mkrescue` ISO (BIOS+UEFI) | `valtus-0.1.0-amd64.iso` |
| 5 finalize | size policy check, sha256, publish to `releases/` + manifest + logs | release artifacts |

Reproducibility properties: fixed package set (versions drift with the
archive — inherent to rolling package sources; the manifest records what was
built), deterministic configuration (all inputs version-controlled), no
interactive steps, timestamps recorded rather than embedded.

Cache: each stage writes a `zstd` snapshot in the WSL build dir
(`/root/valtus-build/cache/`). Re-run with `--from 3` for configuration-only
iteration (~10 min) without re-downloading packages.

> Build-environment caveat: the project sources live on the Windows filesystem
> (`/mnt/c`, DrvFs), where files default to uid 1000 / mode 777. Stage 3
> normalizes ownership and permissions of every Valtus-added path and the
> rootfs root directory before packaging.

## 3. Boot flow and live-session provisioning

1. GRUB (BIOS or UEFI) → kernel `boot=casper` with serial console enabled.
2. casper locates `/casper/filesystem.squashfs`, unions a tmpfs overlay on
   top, and runs its casper-bottom scripts in the initramfs: `15autologin`
   (appends `[Autologin]` to `/etc/sddm.conf`), `25adduser` (creates the live
   user via `user-setup-apply` seeded from `/etc/casper.conf`, and writes
   `/etc/sudoers.d/casper` granting passwordless sudo).
## 3. Boot flow and live-session provisioning

> **Critical casper caveat (build #4 fix):** `BUILD_SYSTEM` in
> `/etc/casper.conf` is *functional*, not cosmetic. casper-helpers maps
> `BUILD_SYSTEM ∈ {Debian, Ubuntu}` → `MP_QUIET="-q"`; anything else → "",
> which makes casper call `modprobe "" -b overlay`, which kmod rejects and
> the boot dies at "/cow format specified as 'overlay' and no support
> found". It stays "Ubuntu" (verified by smoke test); Valtus branding lives
> in FLAVOUR/USERNAME/HOST and os-release.

1. GRUB (BIOS or UEFI) → kernel `boot=casper` with serial console enabled.
   - **initramfs hook** `27valtus-credentials` (best effort): sets the
     documented password via `chpasswd`, removes the casper sudoers grant.
   - **systemd unit** `valtus-live-credentials.service` (authoritative; runs
     `Before=sddm.service`): re-sets the documented password, removes
     `/etc/sudoers.d/casper`, and disables autologin by writing
     `/etc/sddm.conf.d/zz-valtus-no-autologin.conf` (SDDM merges conf.d after
     `/etc/sddm.conf`, so an empty `User=` disables autologin) plus stripping
     any `[Autologin]` block from `/etc/sddm.conf`.
   - The unit does **not** use `ConditionUser=` — systemd evaluates it false in
     the live-boot namespace even though the casper-created user exists (it
     silently skipped the unit in early builds). The script itself gates on
     the live-only `/cow` mount plus user existence, so installed systems are
     never touched.
4. SDDM starts → Plasma session (Wayland; X11 via the session menu).

## 4. Desktop configuration model

All desktop defaults ship in `/etc/skel` (copied by `user-setup-apply` when
casper creates the live user):

| File | Effect |
|---|---|
| `.config/kdeglobals` | ValtusDark color scheme, Breeze widget/icons, Noto Sans 10pt fonts |
| `.config/plasmarc` | default Plasma theme |
| `.config/kwinrc` | Breeze window decorations |
| `.config/kscreenlockerrc` | Valtus wallpaper on the lock screen |
| `.config/plasma-org.kde.plasma.desktop-appletsrc` | bottom panel: kickoff launcher (favorites), icon-only task manager, system tray, digital clock |
| `.config/konsolerc` + `.local/share/konsole/Valtus.profile` | branded terminal profile |
| `.config/dolphinrc` | full-path location bar (professional file-management default) |
| `.config/autostart/valtus-welcome.desktop` | welcome application at first login |

System-level branding: `/usr/share/plasma/look-and-feel/org.valtus.desktop`
(kcminputrc-consistent defaults incl. wallpaper), `/usr/share/wallpapers/valtus`
(wallpaper image package, PNG 1920×1080 + 3840×2160 rendered from SVG),
`/usr/share/color-schemes/ValtusDark.colors`, SDDM theme + background
(`/etc/sddm.conf.d/valtus.conf`).

Default applications (one per function, verified available in noble):

| Function | Application |
|---|---|
| Terminal | Konsole |
| Files | Dolphin |
| Editor | Kate |
| Documents | Okular |
| Web | Falkon |
| Media | VLC |
| Archives | Ark |
| Screenshots | Spectacle (kde-spectacle) |
| System settings | KDE System Settings |
| System information | KInfoCenter |
| Monitoring | Plasma System Monitor |
| Software | Plasma Discover (apt/packagekit backend) |
| Calculator | KCalc |

No SSH server, no remote desktop server, no telemetry, no account/cloud
services are installed or enabled.

## 5. Security model

Valtus treats "focused on security" as: strong defaults, least services,
verified package supply chain, and a documented, honest threat model. It does
not claim to be "unhackable"; it minimizes exposure.

### 5.1 Live-session credentials (by design)

The live user **valtus** has the fixed password recorded in `config/valtus.env`
(the same value shown in the welcome application and documented in
INSTALLATION.md). Requirement traceability: the project owner requires
known, hardcoded credentials (env-file pattern — one authoritative file, no
inline values anywhere in scripts).

Threat analysis:
- The ISO has **no network services listening** (no sshd; ufw default-deny
  incoming) so the credential grants local console use only.
- An attacker with local access to a live-boot session already controls the
  machine (outsiders cannot reach it remotely).
- Installed systems (installer milestone) will require each user to choose
  their own password; PAM enforces `minlen=10 minclass=3` via pwquality.

### 5.2 Hardening measures

| Measure | Implementation |
|---|---|
| Root login disabled | `passwd -l root` at build time (locked shadow entry) |
| Privilege escalation | sudo group membership, password required (casper's NOPASSWD grant removed) |
| No autologin | SDDM conf.d override (see §3) |
| Firewall | `ufw` enabled at build; default-deny incoming / allow outgoing |
| Security updates | unattended-upgrades enabled (`20auto-upgrades`) |
| MAC | AppArmor (Ubuntu default LSM; verified at test) |
| Kernel/userspace hardening | `90-valtus-hardening.conf` sysctl set (kptr_restrict 2, dmesg_restrict 1, unprivileged_bpf off, bpf_jit_harden, ptrace_scope 1, ASLR, protected symlinks, network stack) |
| Password policy | `pwquality.conf.d/90-valtus.conf` (length/class/badwords/dictcheck) |
| Supply chain | all packages GPG-verified from official Ubuntu archive; no third-party repos |
| Machine identity | `/etc/machine-id` truncated — regenerated on first boot |

### 5.3 Known limitations (honest list)

- The live-session password is constant by design (see 5.1) — acceptable for a
  local live session, unacceptable for a multi-user server; the installer must
  avoid reusing it.
- casper intentionally disables some notify/update services inside live
  sessions (`53disable_unattended_upgrades`, `31disable_update_notifier`);
  these are re-evaluated for the installer milestone.
- No full-disk-encryption / secure-boot signing yet.
- 0.1.0 includes the standard Ubuntu attack surface of an ordinary desktop;
  "hard to hack" here means least-privilege defaults and no out-of-the-box
  attack surface, not novel security research.
- KDE Wallet first-login prompt is not pre-seeded (choose "classic wallet" or
  blowfish with your password; avoid an empty-password wallet).

## 6. Known deviations from upstream

- `/etc/os-release` keeps `ID=ubuntu`/`VERSION_CODENAME=noble` deliberately
  so Ubuntu tooling (apt templates, do-release-upgrades, PPA add-apt-repository,
  discovery backends) keeps working while `NAME`/`PRETTY_NAME` say Valtus.
- casper runs in live sessions and leaves `/etc/casper.conf` — inert on
  installed systems.
