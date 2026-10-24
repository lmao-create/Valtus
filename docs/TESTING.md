# Valtus testing

Three layers: (1) static repository checks, (2) static ISO validation,
(3) automated VM boot tests. Evidence is preserved under `logs/`.

Status legend: **PASS** executed and observed · **FAIL** observed failing ·
**BLOCKED** could not run in this environment · **NOT RUN** not yet executed.

## 1. VM configuration (recommended, per project spec)

| Setting | Value |
|---|---|
| Hypervisor | QEMU/KVM (`qemu-system-x86_64 -enable-kvm -cpu host`, WSL2 nested virt) |
| Machine | q35, virtio-gpu, virtio-net-pci |
| Firmware | GRUB hybrid (SeaBIOS BIOS + UEFI EFI boot paths both on ISO) |
| RAM | 2048 MB (host has 8 GB; WSL 3.7 GB) |
| vCPUs | 2 |
| Disk | none for live boot; disposable 64 GB qcow2 offered for install tests |
| Network | `-nic user,model=virtio-net-pci` (QEMU user-mode DHCP + DNS) |
| Console | serial to a log file; monitor socket for screendumps |
| Also compatible | VirtualBox (VMSVGA graphics) — per user testing on the host; not automated on the build host this milestone |

Lower-resource configuration (1 vCPU / 1536 MB) is listed as pending in §5.

## 2. Test matrix

### 2.1 Static / repository tests — `bash tests/smoke_test.sh`

| # | Check | Result |
|---|---|---|
| S1 | Project structure & required files exist | PASS |
| S2 | `config/distro.conf` parses; required keys; ISO9660-safe label | PASS |
| S3 | `config/valtus.env` parses; live credential present | PASS |
| S4 | No inline credentials in scripts/config (env-file pattern) | PASS |
| S5 | No CRLF line endings in the tree | PASS |
| S6 | Package lists parse and are non-trivial | PASS |
| S7 | Branding assets exist and are valid | PASS |
| S8 | Security invariants present (sysctl, pwquality, no NOPASSWD, no ssh server) | PASS |
| S9 | VM harness cleanup has guarded path | PASS |

(43 assertions passed on 2026-10-19; re-run after re-commit at 0.1.0.)

### 2.2 ISO validation — `bash scripts/validate.sh <iso>`

| # | Check | Result |
|---|---|---|
| V1 | ISO exists, size plausible and within policy limit (≤ 4 GiB) | PASS |
| V2 | SHA-256 computed / matches sidecar | PASS |
| V3 | ISO9660 filesystem readable by xorriso | PASS |
| V4 | `/casper/vmlinuz`, `/casper/initrd`, `/casper/filesystem.squashfs` present | PASS |
| V5 | GRUB EFI (`/efi/boot/bootx64.efi`) and BIOS boot files present | PASS |
| V6 | El Torito (BIOS) boot record present | PASS |

Result on `releases/valtus-0.1.0-amd64.iso`: **11/11 passed**.

### 2.3 Automated VM test — `bash scripts/test_vm.sh <iso>`

Every check requires a matching string in the live serial log; a check is
marked PASS only if the guest produced that evidence. **Results are recorded
in `logs/vm-test-*/RESULTS.txt`** and summarized here after each run.

| # | Check | Evidence pattern | Result |
|---|---|---|---|
| B1 | QEMU process starts from the ISO | pid alive | PENDING |
| B2 | GRUB bootloader menu appears | `GRUB` on serial | PENDING |
| B3 | Linux boots to console getty | `login:` prompt | PENDING |
| B4 | Serial login with documented live credential | `valtus@valtus` | PENDING |
| B5 | Identity: os-release says Valtus 0.1.0 | `PRETTY_NAME="Valtus 0.1.0` | PENDING |
| B6 | Wallpaper/look-and-feel packages installed | file paths | PENDING |
| B7 | systemd running, no failed units | `is-system-running`, 0 units | PENDING |
| B8 | Network interface + DHCP address | `nmcli`, `ip address` | PENDING |
| B9 | DNS resolves and ICMP works | `getent hosts`, `1 received` | PENDING |
| B10 | ufw active | `Status: active` | PENDING |
| B11 | sudo requires the documented password | root uid via sudo | PENDING |
| B12 | Root account locked | `^root:!` in shadow | PENDING |
| B13 | AppArmor listed in `/sys/kernel/security/lsm` | `apparmor` | PENDING |
| B14 | unattended-upgrades enabled | is-enabled/is-active | PENDING |
| B15 | apt update works inside the guest | `Reading package lists` | PENDING |
| B16 | apt installs a package inside the guest | `Setting up` | PENDING |
| B17 | Default applications on PATH (12 apps) | `command -v` output | PENDING |
| B18 | Plasma session after SDDM sendkey login; graphical session registered | screendump + `loginctl` | PENDING |
| B19 | Guest powers off cleanly | `Power down` / QEMU exit | PENDING |

### 2.4 Manual / visual checks

| # | Check | Method | Result |
|---|---|---|---|
| M1 | Login screen shows Valtus branding, valtus user | screendump at SDDM | PENDING |
| M2 | Desktop renders: wallpaper, panel, launcher, readability | screendump after login | PENDING |
| M3 | Welcome application appears at first login | screendump | PENDING |

## 3. Evidence artifacts

- `logs/vm-test-<timestamp>/serial.log` — full guest boot/interaction log
- `logs/vm-test-<timestamp>/screens/*.ppm|.png` — monitor screendumps
- `logs/vm-test-<timestamp>/RESULTS.txt` — per-check report with PASS/FAIL
- `logs/build-<timestamp>.log` — full build log
- `releases/valtus-0.1.0-amd64.{iso,iso.sha256,manifest.txt}`

## 4. Reproduce a VM test by hand

```bash
qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 2048 \
  -cdrom releases/valtus-0.1.0-amd64.iso -boot order=d \
  -nic user,model=virtio-net-pci -display none -vga virtio \
  -serial unix:/tmp/serial.sock,server,nowait \
  -monitor unix:/tmp/monitor.sock,server,nowait
```

VirtualBox equivalent: New VM → Linux/Ubuntu (64-bit), 4 GB RAM, 2 CPUs,
**VMSVGA** graphics, 64 MB video memory, attach the ISO, boot, log in as
`valtus` / `valtus`.

## 5. Pending / not covered this milestone

- VirtualBox host automation (not installed on build host).
- Low-resource VM (1 vCPU, 1536 MB).
- Installation to a disposable disk (installer milestone).
- UEFI-only boot differential (BIOS path automated).
- Power management / suspend (irrelevant on VMs).
- Printers, scanners, Bluetooth, sound capture (hardware dependent).
- FIPS-style security auditing toolchain (out of scope for 0.1.0).

## 6. Results

_Actual runs are recorded here; nothing is asserted without evidence._

| Run | Date | Scope | Summary |
|---|---|---|---|
| Static smoke | 2026-10-19 | repository checks | 43/43 assertions passed (55 with overlay-layout checks) |
| Build #1 | 2026-10-19 16:42 | full build | completed; found `/etc` world-writable defect (fixed build #2) |
| Build #2 | 2026-10-19 17:42 | stages 3–5 rebuild | completed; found rootfs root dir 777/uid-1000 (fixed build #3) |
| Build #3–#4 | 2026-10-20 | stages 3–5 rebuilds | completed; VM test #1 **FAIL: “/cow format specified as 'overlay' and no support found”** — root-caused to `BUILD_SYSTEM="Valtus"` in casper.conf (casper then passes an empty `MP_QUIET` to `modprobe -b overlay`); fixed with BUILD_SYSTEM=Ubuntu + smoke guard |
| VM test #2 | 2026-10-21 | full boot | credentials unit skipped (`ConditionUser` false in live namespace) → fixed (gate in script) |
| VM test #3 | 2026-10-23 | full boot + login | **boot ✓, serial login ✓, 29 passed / 12 failed** — 10 harness bugs + 2 real OS gaps (`ping` missing; Ethernet unmanaged by NM) — all fixed |
| GUI capture | 2026-10-24 | desktop screenshot | **PASS** — live desktop captured from the shipped ISO via the automated-test GRUB entry (`screenshots/valtus-desktop.png`, 1280×800); panel + Valtus wallpaper visible |
| VM test #4 | 2026-10-24 | full boot + in-guest | **34 passed / 5 failed** — all 5 were harness bugs, each confirmed correct in-guest: failed-units count `0` (pattern), root lock `root:*` (marker-line truncation), curl `200 OK` (wrong pattern), apt install (timing), poweroff (broadcast message, not "reboot: Power down"). Harness fixed |
| VM test #5 | 2026-10-24 | final verification | **37 passed / 2 failed** — both remaining failures were harness windowing artifacts (`tail -400` excluded early checks); the in-guest evidence (`0` failed units, `200 OK` from curl) was confirmed present in the serial log. Final run with whole-log search: see `logs/vm-test-*/RESULTS.txt` |

### Antivirus verification (in the live image)

| Check | Result |
|---|---|
| 3 packages installed and configured (`ii`) | PASS — build log `rc1=0 rc2=0 rc3=0 ii=3` |
| Packages disjoint (no file conflicts) | PASS — helper owns `/usr/libexec/…` + polkit only |
| App entry point `/usr/bin/valtus-security` | PASS — runs `--version` |
| PySide6 shim (PyQt6-backed) | PASS |
| freshclam signatures | PASS — 3,642,895 signatures (108 MB) |
| **EICAR detection** | PASS — `Detections: 1; Eicar-Test-Signature` |
| Honest status reporting | PASS — reports missing components accurately |
