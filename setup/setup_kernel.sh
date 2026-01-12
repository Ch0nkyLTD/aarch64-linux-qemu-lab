#!/bin/bash

# ==============================================================================
# AArch64 Linux Kernel Builder
# ==============================================================================
# Downloads Linux 6.6 and builds it with debugging options enabled.
#
# Usage: ./setup/setup_kernel.sh
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(dirname "$SCRIPT_DIR")"
KERNEL_VERSION="v6.6"
KERNEL_DIR="$LAB_ROOT/linux-6.6"

cd "$LAB_ROOT"

# --- Check if kernel already exists ---
if [ -d "$KERNEL_DIR" ]; then
    echo ">>> Kernel source already exists at $KERNEL_DIR"
    read -p "    Rebuild? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "    Skipping kernel download."
        SKIP_DOWNLOAD=1
    fi
fi

# --- Download Kernel ---
if [ -z "$SKIP_DOWNLOAD" ]; then
    echo ">>> Downloading Linux kernel $KERNEL_VERSION..."
    if [ -d "$KERNEL_DIR" ]; then
        rm -rf "$KERNEL_DIR"
    fi
    git clone --depth 1 --branch "$KERNEL_VERSION" \
        https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
        "$KERNEL_DIR"
fi

cd "$KERNEL_DIR"

# --- Set Cross-Compilation Environment ---
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

echo ">>> Configuring kernel..."

# Generate default ARM64 config
make defconfig

# --- Apply Debug-Friendly Options ---
echo ">>> Enabling debug options..."

# Debug info for GDB
./scripts/config --enable CONFIG_DEBUG_INFO
./scripts/config --enable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
./scripts/config --enable CONFIG_GDB_SCRIPTS
./scripts/config --enable CONFIG_DEBUG_SECTION_MISMATCH

# KGDB support
./scripts/config --enable CONFIG_KGDB
./scripts/config --enable CONFIG_KGDB_SERIAL_CONSOLE

# Disable KASLR (makes debugging easier)
./scripts/config --disable CONFIG_RANDOMIZE_BASE

# Frame pointers (better stack traces)
./scripts/config --enable CONFIG_FRAME_POINTER

# Enable loadable module support
./scripts/config --enable CONFIG_MODULES
./scripts/config --enable CONFIG_MODULE_UNLOAD

# 9P filesystem support (for shared folders)
./scripts/config --enable CONFIG_NET_9P
./scripts/config --enable CONFIG_NET_9P_VIRTIO
./scripts/config --enable CONFIG_9P_FS
./scripts/config --enable CONFIG_9P_FS_POSIX_ACL

# Virtio support
./scripts/config --enable CONFIG_VIRTIO
./scripts/config --enable CONFIG_VIRTIO_PCI
./scripts/config --enable CONFIG_VIRTIO_BLK
./scripts/config --enable CONFIG_VIRTIO_NET

# Optional: KASAN (memory error detector) - can slow things down
# ./scripts/config --enable CONFIG_KASAN
# ./scripts/config --enable CONFIG_KASAN_INLINE

# Re-sync config
make olddefconfig

# --- Build ---
echo ">>> Building kernel (this takes ~10-20 minutes)..."
make -j$(nproc) Image vmlinux modules

echo ""
echo "=============================================================================="
echo "  SUCCESS: Kernel built!"
echo "=============================================================================="
echo ""
echo "  Kernel image:  $KERNEL_DIR/arch/arm64/boot/Image"
echo "  Debug symbols: $KERNEL_DIR/vmlinux"
echo ""
echo "  Next steps:"
echo "    1. Run 'sudo ./setup/setup_debian.sh' to create rootfs"
echo "    2. Run 'make run' to start the VM"
echo ""
echo "=============================================================================="
