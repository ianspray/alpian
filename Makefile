# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Ian Spray

.PHONY: all build-% clean distclean container-build container-run help

BUILD_DIR := $(shell pwd)
CACHE_DIR := $(BUILD_DIR)/cache
OUTPUT_DIR := $(BUILD_DIR)/output
SCRIPTS_DIR := $(BUILD_DIR)/scripts
CONFIG_DIR := $(BUILD_DIR)/config

BOARDS := rock5b rock5c rock5e rock3b rpi4 rpi5

CONTAINER_RUNTIME ?= docker
CONTAINER_NAME := alpian-builder

all: help

help:
	@echo "Alpian Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  container-build   - Build the Docker/Podman container"
	@echo "  container-run     - Run interactive container shell"
	@echo "  fetch             - Fetch all remote assets (kernel, uboot, etc.)"
	@echo "  uboot             - Build U-Boot for target boards"
	@echo "  kernel            - Build Linux kernel for target boards"
	@echo "  apk               - Build custom APK packages"
	@echo "  root              - Build root filesystem"
	@echo "  image             - Build final disk image"
	@echo "  build-<board>     - Build image for specific board"
	@echo "  all-boards        - Build images for all boards"
	@echo "  clean             - Clean build artifacts"
	@echo "  distclean         - Clean everything including cache"
	@echo ""

container-build:
	$(CONTAINER_RUNTIME) build -t alpian-builder -f build/Dockerfile .

container-run:
	$(CONTAINER_RUNTIME) run -it --rm \
		-v $(CACHE_DIR):/var/cache/distfiles \
		-v $(OUTPUT_DIR):/output \
		-v $(BUILD_DIR):/build \
		-w /build \
		--privileged \
		alpian-builder

fetch:
	@echo "=== Stage: Fetch remote assets ==="
	@mkdir -p $(CACHE_DIR)/{kernel,uboot,apk,rootfs}
	@for board in $(BOARDS); do \
		$(SCRIPTS_DIR)/fetch/$$board.sh; \
	done

uboot:
	@echo "=== Stage: Build U-Boot ==="
	@for board in $(BOARDS); do \
		$(SCRIPTS_DIR)/uboot/$$board.sh; \
	done

kernel:
	@echo "=== Stage: Build Linux kernel ==="
	@for board in $(BOARDS); do \
		$(SCRIPTS_DIR)/kernel/$$board.sh; \
	done

apk:
	@echo "=== Stage: Build custom APK packages ==="
	@$(SCRIPTS_DIR)/apk/build.sh

root:
	@echo "=== Stage: Build root filesystem ==="
	@for board in $(BOARDS); do \
		$(SCRIPTS_DIR)/root/$$board.sh; \
	done

image:
	@echo "=== Stage: Build final disk image ==="
	@for board in $(BOARDS); do \
		$(SCRIPTS_DIR)/image/$$board.sh; \
	done

build-%:
	@board=$(filter-out build-,$(MAKECMDGOALS)); \
	for b in $(BOARDS); do \
		if [ "$$b" = "$$board" ]; then \
			$(SCRIPTS_DIR)/fetch/$$board.sh; \
			$(SCRIPTS_DIR)/uboot/$$board.sh; \
			$(SCRIPTS_DIR)/kernel/$$board.sh; \
			$(SCRIPTS_DIR)/apk/build.sh; \
			$(SCRIPTS_DIR)/root/$$board.sh; \
			$(SCRIPTS_DIR)/image/$$board.sh; \
			break; \
		fi; \
	done

all-boards:
	@for board in $(BOARDS); do \
		make build-$$board; \
	done

clean:
	@echo "=== Cleaning build artifacts ==="
	@rm -rf $(OUTPUT_DIR)/*
	@rm -rf $(BUILD_DIR)/rootfs

distclean: clean
	@echo "=== Cleaning cache ==="
	@rm -rf $(CACHE_DIR)/*

.PHONY: help container-build container-run fetch uboot kernel apk root image build-% all-boards clean distclean