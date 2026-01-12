# ==============================================================================
# Common Kernel Module Build Rules
# ==============================================================================
# Include this from your module's Makefile:
#
#   MODULE_NAME := mymodule
#   include ../module.mk
#
# Or just put a single .c file in a directory and it auto-detects the name.
# ==============================================================================

# Auto-detect module name from directory if not set
MODULE_NAME ?= $(notdir $(CURDIR))

# Paths
MODULES_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
LAB_ROOT := $(abspath $(MODULES_DIR)/..)
KDIR := $(LAB_ROOT)/linux-6.6

# Toolchain
ARCH := arm64
CROSS_COMPILE := aarch64-linux-gnu-

# Build directories
BUILD_DIR := build
BIN_DIR := bin

# Find all .c files in current directory
SRCS := $(wildcard *.c)

.PHONY: all clean install

all:
	@if [ ! -d "$(KDIR)" ]; then \
		echo "Error: Kernel source not found at $(KDIR)"; \
		echo "Run 'make kernel' from lab root first."; \
		exit 1; \
	fi
	@echo "=== Building module: $(MODULE_NAME) ==="
	@mkdir -p $(BUILD_DIR) $(BIN_DIR)
	@cp $(SRCS) $(BUILD_DIR)/
	@echo "obj-m += $(MODULE_NAME).o" > $(BUILD_DIR)/Makefile
	@$(MAKE) -C $(KDIR) \
		M=$(CURDIR)/$(BUILD_DIR) \
		ARCH=$(ARCH) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		modules
	@cp $(BUILD_DIR)/$(MODULE_NAME).ko $(BIN_DIR)/
	@echo "=== Success: $(BIN_DIR)/$(MODULE_NAME).ko ==="

clean:
	@echo "=== Cleaning $(MODULE_NAME) ==="
	@rm -rf $(BUILD_DIR) $(BIN_DIR)

# Copy to shared folder for easy loading in guest
install: all
	@mkdir -p $(LAB_ROOT)/shared/modules
	@cp $(BIN_DIR)/$(MODULE_NAME).ko $(LAB_ROOT)/shared/modules/
	@echo "=== Installed to shared/modules/$(MODULE_NAME).ko ==="
