# ==============================================================================
# AArch64 Kernel Development Lab - Makefile
# ==============================================================================
#
# Quick Start:
#   make deps          Install dependencies
#   make kernel        Build the kernel
#   make rootfs        Create Debian rootfs (requires sudo)
#   make run           Start VM (debug mode)
#   make shared        Start VM with shared folder
#
# ==============================================================================

.PHONY: help deps kernel rootfs run debug shared nodebug reset \
        snapshot restore modules modules-clean modules-install \
        new-module clean info

# Auto-discover modules (excluding _template)
MODULE_DIRS := $(shell find modules -maxdepth 1 -mindepth 1 -type d ! -name '_template' 2>/dev/null)

# Default target
help:
	@echo "=============================================================================="
	@echo "  AArch64 Kernel Development Lab"
	@echo "=============================================================================="
	@echo ""
	@echo "  SETUP:"
	@echo "    make deps        Install build dependencies"
	@echo "    make kernel      Download and build Linux 6.6 kernel"
	@echo "    make rootfs      Create Debian rootfs (requires sudo)"
	@echo "    make all         Run deps, kernel, and rootfs"
	@echo ""
	@echo "  RUN:"
	@echo "    make run         Start VM in debug mode (GDB on :1234)"
	@echo "    make shared      Start VM with shared folder + debug"
	@echo "    make nodebug     Start VM without GDB (immediate boot)"
	@echo "    make debug       Launch GDB and connect to VM"
	@echo ""
	@echo "  SNAPSHOTS:"
	@echo "    make snapshot NAME=<name>   Create a snapshot"
	@echo "    make restore NAME=<name>    Restore to a snapshot"
	@echo "    make snapshots              List all snapshots"
	@echo "    make reset                  Reset to golden image"
	@echo ""
	@echo "  MODULES:"
	@echo "    make modules               Build all kernel modules"
	@echo "    make modules-install       Build and copy to shared/modules/"
	@echo "    make modules-clean         Clean module builds"
	@echo "    make new-module NAME=foo   Create new module from template"
	@echo "    make module-<name>         Build a specific module"
	@echo ""
	@echo "  UTILITIES:"
	@echo "    make info        Show image information"
	@echo "    make ssh         SSH into running VM"
	@echo "    make clean       Clean build artifacts"
	@echo ""
	@echo "  Detected modules: $(notdir $(MODULE_DIRS))"
	@echo "=============================================================================="

# ==============================================================================
# Setup Targets
# ==============================================================================

deps:
	@echo ">>> Installing dependencies..."
	sudo apt update
	sudo apt install -y \
		qemu-system-aarch64 qemu-system-arm \
		gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
		gdb-multiarch \
		build-essential bison flex libncurses-dev libssl-dev \
		libelf-dev git cpio bc \
		debootstrap qemu-user-static binfmt-support qemu-utils

kernel:
	@echo ">>> Building kernel..."
	./setup/setup_kernel.sh

rootfs:
	@echo ">>> Creating Debian rootfs (requires sudo)..."
	sudo ./setup/setup_debian.sh

all: deps kernel rootfs
	@echo ">>> Setup complete!"

# ==============================================================================
# Run Targets
# ==============================================================================

run:
	@./scripts/start.sh --debug

shared:
	@./scripts/start.sh --shared --debug

nodebug:
	@./scripts/start.sh --no-debug --shared

debug:
	@echo ">>> Starting GDB..."
	gdb-multiarch -x .gdbinit

# ==============================================================================
# Snapshot Targets
# ==============================================================================

snapshot:
ifndef NAME
	@echo "Error: NAME required. Usage: make snapshot NAME=mysnap"
	@exit 1
endif
	@./scripts/snapshot.sh create $(NAME)

restore:
ifndef NAME
	@echo "Error: NAME required. Usage: make restore NAME=mysnap"
	@exit 1
endif
	@./scripts/restore.sh $(NAME)

snapshots:
	@./scripts/snapshot.sh list

reset:
	@./scripts/restore.sh --reset

# ==============================================================================
# Module Targets
# ==============================================================================

# Build all modules
modules:
	@echo ">>> Building all kernel modules..."
	@for dir in $(MODULE_DIRS); do \
		if [ -f "$$dir/Makefile" ]; then \
			$(MAKE) -C "$$dir" || exit 1; \
		fi \
	done
	@echo ">>> All modules built successfully"

# Build and install to shared folder
modules-install: modules
	@echo ">>> Installing modules to shared/modules/..."
	@mkdir -p shared/modules
	@for dir in $(MODULE_DIRS); do \
		if [ -f "$$dir/Makefile" ]; then \
			$(MAKE) -C "$$dir" install; \
		fi \
	done
	@echo ">>> Modules available in shared/modules/"
	@echo ">>> In guest: mount-shared && insmod /mnt/modules/<name>.ko"

# Clean all modules
modules-clean:
	@echo ">>> Cleaning kernel modules..."
	@for dir in $(MODULE_DIRS); do \
		if [ -f "$$dir/Makefile" ]; then \
			$(MAKE) -C "$$dir" clean 2>/dev/null || true; \
		fi \
	done

# Create new module from template
new-module:
ifndef NAME
	@echo "Error: NAME required. Usage: make new-module NAME=mymodule"
	@exit 1
endif
	@./scripts/new-module.sh $(NAME)

# Build specific module: make module-hello
module-%:
	@if [ -d "modules/$*" ]; then \
		$(MAKE) -C "modules/$*"; \
	else \
		echo "Error: Module '$*' not found in modules/"; \
		exit 1; \
	fi

# ==============================================================================
# Utility Targets
# ==============================================================================

ssh:
	@ssh -p 10022 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@localhost

info:
	@echo ">>> Runtime image info:"
	@./scripts/snapshot.sh info
	@echo ""
	@echo ">>> Snapshots:"
	@./scripts/snapshot.sh list

clean:
	@echo ">>> Cleaning build artifacts..."
	rm -f debian-runtime.qcow2
	rm -rf mnt_rootfs shared/modules
	$(MAKE) modules-clean

distclean: clean
	@echo ">>> Removing all generated files..."
	rm -f debian-rootfs-base.img debian-rootfs.qcow2
	rm -rf linux-6.6 busybox-*
