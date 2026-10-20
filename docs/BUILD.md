# Building Valtus

This document reproduces the Valtus ISO from scratch. Every step is executed
by scripts in this repository — there is no manual, undocumented step.

## 1. Environment

**Build host:** Debian 12/13 in WSL2 on an x86-64 machine (this project was
developed on Windows 11 + WSL2 Debian 13; any recent Debian/Ubuntu host with
the packages below also works). Build inside the WSL Linux filesystem (not
`/mnt/c`) because `debootstrap` and `chroot` require real Linux filesystem
semantics (device nodes, POSIX permissions, mounts).

### 1.1 Dependencies

```bash
sudo apt-get update
sudo apt-get install -y debootstrap ubuntu-keyring squashfs-tools xorriso \
     grub-pc-bin grub-efi-amd64-bin grub-common mtools rsync wget curl git \
     qemu-system-x86 qemu-utils socat file xz-utils zstd cpio dosfstools \
     librsvg2-bin python3 python3-pil ca-certificates
```

Or: `make deps` from the project root.

Optional (for VM testing): `sudo usermod -aG kvm "$USER"`, then restart WSL.

## 2. Build

```bash
wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/build.sh'
```

or directly inside a native Linux build host:

```bash
sudo bash scripts/build.sh
```

### 2.1 Options

```
--from N    start at stage N (reuse caches from earlier stages)
--to N      stop after stage N
--clean     wipe the WSL build workspace (releases/ untouched)
```

### 2.2 What happens

| Stage | Duration (2-core host, first run) | Result |
|---|---|---|
| 1 bootstrap | ~10 min | minbase noble rootfs |
| 2 packages | ~30 min | full package set incl. kernel, Plasma, casper |
| 3 customize | ~2 min + snapshot | branding, hardening, credentials unit |
| 4 image | ~20 min | ISO (squashfs compression dominates) |
| 5 finalize | ~2 min | checksum, manifest, publish |

First build total: ~60 min on a 2-core laptop. Configuration-only iteration
(`--from 3`): ~10 min.

### 2.3 Where things live

- Logs: `logs/build-<timestamp>.log` (mirrored to the terminal)
- Working rootfs / ISOs during build: `/root/valtus-build` (WSL filesystem)
- Final artifacts: `releases/valtus-0.1.0-amd64.iso` (+ `.sha256`,
  `.manifest.txt`, `.build.log`)

### 2.4 Determinism & reproducibility

- All configuration inputs are version-controlled
  (`config/`, `branding/`, `scripts/`).
- Packages come from the official Ubuntu archive, GPG-verified by
  `debootstrap` (Ubuntu archive keyring) and by apt (signed repositories).
- No interactive prompts, no host state is read into the image.
- Rebuilds produce the same *configuration*; package versions track the
  Ubuntu archive (inherent to live package sources). What was built is
  recorded in `releases/*.manifest.txt` (kernel version, package count, git
  revision, timestamps).
- The previous release is never overwritten without a successful validated
  build; after a VM test passes, promote the release:

```bash
mkdir -p releases/known-good
cp -n releases/valtus-0.1.0-amd64.iso releases/known-good/   # -n keeps the old copy
```

## 3. Validation and testing

```bash
# static validation (no VM)
wsl -d Debian -u root -- bash scripts/validate.sh releases/valtus-0.1.0-amd64.iso

# static repository checks (no root, no WSL)
bash tests/smoke_test.sh

# automated VM boot test (QEMU/KVM)
wsl -d Debian -u root -- bash scripts/test_vm.sh releases/valtus-0.1.0-amd64.iso
```

`validate.sh` checks size policy, checksum, ISO9660 structure, GRUB EFI/BIOS
boot files and the casper boot chain. `test_vm.sh` boots the ISO in QEMU with
KVM, logs the serial console, takes monitor screendumps, logs in with the
documented live credential, runs the in-guest checks from
docs/TESTING.md and writes `logs/vm-test-<timestamp>/RESULTS.txt`.

## 4. Failure handling

`build.sh` aborts on any failed critical step with a non-zero exit and writes
`FAILED during stage <n>` into the log. Stage snapshots let you resume from
the last good stage (`--from N`) instead of re-downloading packages.

Common failures and fixes: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## 5. Safety of the build

- The build never reads host secrets, SSH keys, or credentials into the image.
- The only credential in the build comes from `config/valtus.env` (live
  user, fixed documented password) — see ARCHITECTURE.md §5.1.
- Destructive operations target only the WSL build workspace
  (`/root/valtus-build`) or release files matching the Valtus ISO name; the
  build never touches Windows host partitions or user data. The VM harness
  has a guarded cleanup that only removes `/root/valtus-vm-test-*`.
