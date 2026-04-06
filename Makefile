# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray

VERSION                ?= v3.23
CACHE_DIR              ?= cache
APK_CACHE_DIR          ?= $(CACHE_DIR)/apk-cache
APK_LIST               ?= $(CACHE_DIR)/apklist.txt
LINUX_CACHE_DIR        ?= $(CACHE_DIR)/linux/$(KERNEL_DIR)
BUILD_VOLUME           ?= alpian-build-volume
UBOOT_CACHE_DIR        ?= $(CACHE_DIR)/u-boot
ROCKCHIP_TPL_CACHE_DIR ?= $(CACHE_DIR)/rockchip-tpl
SCAN_DIRS              ?= .
CLONE_DEPTH            ?= 50

BOARD		       ?= e25

include boards/$(BOARD)/$(BOARD).env

.PHONY: build-volume build-tools image build build-linux build-uboot build-rootfs build-bootfs fetch fetch-apk fetch-linux fetch-uboot fetch-rockchip-tpl clean help abuild-keys

# Scan Containerfiles and shell scripts in SCAN_DIRS, resolve deps, download .apk files.
fetch-apk:
	podman run --rm \
		-v $(CURDIR)/cache/apk-cache:/etc/apk/cache \
		-v $(CURDIR)/cache:/cache \
		-v $(CURDIR):/src:ro \
		-v $(CURDIR)/tools:/tools:ro \
		alpine:3.23.3 \
		/tools/fetch-apks.sh

build-tools: $(APK_LIST) tools/Containerfile tools/abuild-pkg.sh tools/alpian-build.sh tools/fetch-apks.sh
	podman build \
		-f tools/Containerfile \
		-v $(CURDIR)/cache/apk-cache:/etc/apk/cache \
		-v $(CURDIR)/tools:/tools:ro \
		-t alpian-builder .

build/aports/abuild.rsa:
	openssl genrsa -out build/aports/abuild.rsa 4096

build/aports/abuild.rsa.pub: build/aports/abuild.rsa
	openssl rsa -in build/aports/abuild.rsa -pubout -out build/aports/abuild.rsa.pub

abuild-keys: build/aports/abuild.rsa build/aports/abuild.rsa.pub

cache/apklist.txt: fetch-apk

build-volume:
	podman volume exists $(BUILD_VOLUME) || podman volume create $(BUILD_VOLUME)

# - - - - - -

fetch-linux:
	mkdir -p $(CURDIR)/$(LINUX_CACHE_DIR); \
	if [ -d $(CURDIR)/$(LINUX_CACHE_DIR)/kernel.git ]; then \
		git -C $(CURDIR)/$(LINUX_CACHE_DIR) fetch; \
	else \
		git -C $(CURDIR)/$(LINUX_CACHE_DIR) \
			clone \
			--bare \
			--depth=$(CLONE_DEPTH) \
			--single-branch \
			--branch $(KERNEL_BRANCH) \
			$(KERNEL_REPO); \
	fi

fetch-uboot:
ifdef UBOOT_REPO
	mkdir -p $(CURDIR)/$(UBOOT_CACHE_DIR); \
	if [ -d $(CURDIR)/$(UBOOT_CACHE_DIR)/u-boot.git ]; then \
		git -C $(CURDIR)/$(UBOOT_CACHE_DIR) fetch; \
	else \
		git -C $(CURDIR)/$(UBOOT_CACHE_DIR) \
			clone \
			--bare \
			--depth=$(CLONE_DEPTH) \
			--single-branch \
			--branch $(UBOOT_BRANCH) \
			$(UBOOT_REPO); \
	fi
else
	@echo "UBOOT_REPO not set - skipping"
endif

fetch-rockchip-tpl:
ifdef ROCKCHIP_TPL_REPO
	mkdir -p $(CURDIR)/$(ROCKCHIP_TPL_CACHE_DIR); \
	if [ -d $(CURDIR)/$(ROCKCHIP_TPL_CACHE_DIR)/rkbin.git ]; then \
		git -C $(CURDIR)/$(ROCKCHIP_CACHE_DIR) fetch; \
	else \
		git -C $(CURDIR)/$(ROCKCHIP_TPL_CACHE_DIR) \
			clone \
			--bare \
			--depth=$(CLONE_DEPTH) \
			--single-branch \
			--branch $(ROCKCHIP_TPL_BRANCH) \
			$(ROCKCHIP_TPL_REPO); \
	fi
else
	@echo "ROCKCHIP_TPL_REPO not set - skipping"
endif

# FIXME: this should also depend upon build-tools but only when that image creation
# can be skipped by the make rules when nothing has changed in the apk cache, but
# that may end up being circular in that the container image is needed for both
# fetch-linux and fetch-uboot, but the build depends upon fetch-apk
fetch: fetch-apk fetch-linux fetch-uboot fetch-rockchip-tpl

# - - - - - -

# build the new system (NB: may be better to break this out into multiple
# stages for easier tinkering, but happening inside a single container
# invocation makes it easier to debug to begin with)
build: build-tools fetch-linux fetch-uboot fetch-rockchip-tpl build-volume
	podman run --rm -it \
		-v $(CURDIR)/cache:/cache \
		-v $(CURDIR)/boards:/boards:ro \
		-v $(CURDIR)/cache/apk-cache:/etc/apk/cache \
		-v $(BUILD_VOLUME):/src \
		-v $(CURDIR)/build:/build \
		-v $(CURDIR)/out:/out \
		-e BOARD=$(BOARD) \
		alpian-builder \
		alpian-build.sh

# - - - - - -

# tidy up the build tooling and local APK's
clean:
	podman rmi alpian-builder \
	rm -rf build/apk/*

# tidy up both the build tooling and all local caches (ie: revert to a clean
# 'just checked out' state)
distclean: clean
	podman volume rm -f $(BUILD_VOLUME) \
	rm -rf $(APK_CACHE_DIR) $(LINUX_CACHE_DIR) $(UBOOT_CACHE_DIR) build/aports/abuild.rsa build/aports/abuild.rsa.pub

# FIXME: ALL OF THE HELP TEXT IS INCORRECT
# try to offer guidance without needing a text editor
help:
	@echo "Targets:"
	@echo "  make abuild-keys  ..."
	@echo "  make build-tools  ..."
	@echo "  make build        ..."
	@echo "  make fetch-apk    scan + download packages to $(APK_CACHE_DIR)"
	@echo "  make clean        remove build container and local apk builds"
	@echo "  make distclean    remove build container and all caches"
	@echo ""
	@echo "Variables:"
	@echo "  VERSION=$(VERSION)	Alpine version"
	@echo "  SCAN_DIRS=$(SCAN_DIRS)	paths to scan for APK's"
	@echo "  BOARD=$(BOARD)	The SBC to target"
	@echo ""
	@echo "  make fetch VERSION=v3.23 SCAN_DIRS='./services/api ./services/worker'"
