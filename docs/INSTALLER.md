# Valtus installer — architecture & testing

## Status

**Shipped and integrated.** Calamares 3.3.5 (noble) with Valtus branding,
launcher `/usr/bin/valtus-install`, and menu entry are built into the ISO and
verified present in the image.

**Automated install test: blocked.** The scripted install runs up to the point
of launching Calamares, but the unattended run does not complete. The
diagnosed causes and their state are recorded below so the next session can
finish it.

## 1. Components

| Component | Package | Role |
|---|---|---|
| Installer front-end | `calamares` (3.3.5-0ubuntu4) | Guided install flow, branding |
| Partitioning | `libkpmcore12` (23.08.5) | Partition operations |
| OS detection | `os-prober` | Existing-system detection (dual boot) |
| Bootloader | `grub2-common`, `grub-efi-amd64-signed`, `shim-signed` | UEFI GRUB chain |

## 2. Files in the image

| Path | Purpose |
|---|---|
| `/usr/share/calamares/branding/valtus/` | `branding.desc` ("Install Valtus"), CSS, logo, sidebar |
| `/usr/bin/valtus-install` | launcher — refuses root, uses polkit, no credentials stored |
| `/usr/share/applications/valtus-installer.desktop` | menu entry |
| `/etc/calamares/` | **kept to Calamares' stock defaults** — see §5 |

## 3. Launcher behaviour

`valtus-install` refuses to run as root (privileged actions go through the
Calamares polkit helper) and stores no credentials. The primary account
username/password are chosen by the operator in the installer's users page.

## 4. Automated test

`scripts/test_installer.sh` creates a disposable 64 GiB qcow2, boots the
release ISO with it attached, installs, then boots the installed system with
the ISO detached. It writes serial logs and screenshots to
`logs/installer-test-<timestamp>/`.

## 5. Decision: stock Calamares configuration

An earlier revision shipped a hand-written `settings.conf`. Calamares aborted
at startup with:

```
YAML error yaml-cpp: error at line 7, column 5: bad conversion ... "- model:"
ERROR: FATAL: no sequence set.
```

The shape of `settings.conf` must match the module set the Ubuntu calamares
package ships exactly; a mismatch is fatal. The build therefore **installs only
the branding and launcher** and removes any stale `settings.conf`, leaving
Calamares' guaranteed-compatible built-in defaults in place. The Valtus policy
files (no empty passwords, Valtus bootloader entry) are re-applied as
per-module overrides **once the stock module list is confirmed**.

## 6. Remaining work

1. Boot the rebuilt ISO and confirm Calamares starts (the FIXED build).
2. Complete the unattended install: the remaining defect was that the live
   session's sudo password expanded to empty in the harness — the test must
   use the live-session credential (`config/valtus.env`), not the
   installed-account one, and the base64 config transfer must be verified.
3. Boot the installed system and verify branding, network, AV, hostname.
4. Re-apply the users/bootloader module policy against the stock module list.
5. Test Secure Boot and LUKS (documented; not covered yet).

## 7. Known limitations

- No installer branding in the *slideshow* beyond the sidebar/logo.
- Unattended mode is driven by the `unattended` module; the generated
  credentials are created by the test at run time and never committed.
- Secure Boot verification of the installed system is untested.
