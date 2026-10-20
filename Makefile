# Valtus — convenience targets. Run inside WSL (see docs/BUILD.md):
#   wsl -d Debian -u root -- bash -c 'cd "/mnt/c/Users/hp/Desktop/Custom OS" && make help'
# GNU make is available in the Debian WSL build environment.

SHELL := /bin/bash

DISTRO_ID    := $(shell sed -n 's/^DISTRO_ID="\(.*\)"/\1/p' config/distro.conf)
DISTRO_VER   := $(shell sed -n 's/^DISTRO_VERSION="\(.*\)"/\1/p' config/distro.conf)
DISTRO_ARCH  := $(shell sed -n 's/^DISTRO_ARCH="\(.*\)"/\1/p' config/distro.conf)
ISO_NAME     := $(DISTRO_ID)-$(DISTRO_VER)-$(DISTRO_ARCH).iso
RELEASE_ISO  := releases/$(ISO_NAME)

.PHONY: help deps build clean-build validate checksum vmtest vmtest-quick status check-config smoke test

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make [target]\n\n"} \
	/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

deps: ## Install build dependencies in WSL (root)
	wsl -d Debian -u root -- apt-get update
	wsl -d Debian -u root -- apt-get install -y debootstrap ubuntu-keyring \
		squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin grub-common \
		mtools rsync wget curl git qemu-system-x86 qemu-utils socat file \
		xz-utils zstd cpio dosfstools librsvg2-bin python3 python3-pil ca-certificates

build: ## Build the Valtus ISO (stages 1-5)
	@mkdir -p logs
	wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/build.sh'

build-desktop-only: ## Re-run from stage 3 (uses cached rootfs stages)
	@mkdir -p logs
	wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/build.sh' --from 3

clean-build: ## Remove the WSL build workspace (keeps releases/)
	wsl -d Debian -u root -- rm -rf /root/valtus-build
	@rm -rf logs/vm-test-*

validate: ## Static ISO validation (size, checksum, structure)
	wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/validate.sh' "$(RELEASE_ISO)"

checksum: ## Write SHA-256 sidecar for the release ISO
	wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/checksums.sh' "$(RELEASE_ISO)"

vmtest: ## Boot the release ISO in QEMU and run in-guest checks
	wsl -d Debian -u root -- bash '/mnt/c/Users/hp/Desktop/Custom OS/scripts/test_vm.sh' "$(RELEASE_ISO)" --entry 0 --mem 2048 --timeout 900

status: ## Show build/test artifacts
	@ls -lh releases/ 2>/dev/null || echo "(no releases yet)"
	@tail -5 $$(ls -t logs/build-*.log 2>/dev/null | head -1) 2>/dev/null || echo "(no build logs)"

check-config: ## Validate config files locally (no WSL needed)
	@bash -c 'cd "$(CURDIR)" && test -f config/distro.conf && . config/distro.conf && \
	test -n "$$DISTRO_NAME" && test -n "$$ISO_SIZE_LIMIT_BYTES" && echo "distro.conf OK"'
	@bash -c 'cd "$(CURDIR)" && test -f config/valtus.env && . config/valtus.env && \
	test -n "$$LIVE_USER" && test -n "$$LIVE_USER_PASSWORD" && echo "valtus.env OK"'

smoke: ## Run the static smoke test suite (no WSL needed)
	@bash 'tests/smoke_test.sh'

test: check-config smoke ## Config + smoke tests
