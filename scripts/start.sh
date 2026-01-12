#!/bin/bash

# ==============================================================================
# AArch64 Lab - QEMU Launcher
# ==============================================================================
# Starts the AArch64 VM with various modes.
#
# Usage:
#   ./scripts/start.sh [OPTIONS]
#
# Options:
#   --shared     Enable shared folder (mount at /mnt in guest)
#   --debug      Enable GDB debugging (pauses at startup)
#   --no-debug   Disable GDB (start immediately)
#   --mem SIZE   Set memory size (default: 2G)
#   --cpus N     Set CPU count (default: 2)
#   --help       Show this help
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(dirname "$SCRIPT_DIR")"

# --- Configuration ---
KERNEL="$LAB_ROOT/linux-6.6/arch/arm64/boot/Image"
RUNTIME_IMAGE="$LAB_ROOT/debian-runtime.qcow2"
GOLDEN_IMAGE="$LAB_ROOT/debian-rootfs.qcow2"
SHARE_DIR="$LAB_ROOT/shared"

# Defaults
MEMORY="2G"
CPUS="2"
SHARED=0
DEBUG=1  # Default: debug enabled

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --shared)
            SHARED=1
            shift
            ;;
        --debug)
            DEBUG=1
            shift
            ;;
        --no-debug)
            DEBUG=0
            shift
            ;;
        --mem)
            MEMORY="$2"
            shift 2
            ;;
        --cpus)
            CPUS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --shared     Enable shared folder (./shared -> /mnt in guest)"
            echo "  --debug      Enable GDB server (default, pauses at startup)"
            echo "  --no-debug   Start immediately without GDB"
            echo "  --mem SIZE   Memory size (default: 2G)"
            echo "  --cpus N     CPU count (default: 2)"
            echo ""
            echo "Examples:"
            echo "  $0                    # Basic debug mode"
            echo "  $0 --shared           # With shared folder"
            echo "  $0 --no-debug         # Start immediately"
            echo "  $0 --shared --no-debug --mem 4G"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# --- Verify Prerequisites ---
if [ ! -f "$KERNEL" ]; then
    echo "Error: Kernel not found at $KERNEL"
    echo "Run './setup/setup_kernel.sh' first."
    exit 1
fi

# Auto-create runtime image if missing
if [ ! -f "$RUNTIME_IMAGE" ]; then
    if [ ! -f "$GOLDEN_IMAGE" ]; then
        echo "Error: Golden image not found at $GOLDEN_IMAGE"
        echo "Run 'sudo ./setup/setup_debian.sh' first."
        exit 1
    fi
    echo ">>> Creating runtime image from golden image..."
    qemu-img create -f qcow2 -F qcow2 -b "$(basename "$GOLDEN_IMAGE")" "$RUNTIME_IMAGE" > /dev/null
fi

# --- Build QEMU Command ---
QEMU_ARGS=(
    -M virt
    -cpu cortex-a57
    -m "$MEMORY"
    -smp "$CPUS"
    -nographic
    -kernel "$KERNEL"
    -drive "if=none,file=$RUNTIME_IMAGE,format=qcow2,id=hd0"
    -device "virtio-blk-device,drive=hd0"
    -append "root=/dev/vda rw console=ttyAMA0 nokaslr"
    -netdev "user,id=net0,hostfwd=tcp::10022-:22"
    -device "virtio-net-device,netdev=net0"
)

# Add shared folder if requested
if [ "$SHARED" -eq 1 ]; then
    mkdir -p "$SHARE_DIR"
    QEMU_ARGS+=(
        -virtfs "local,path=$SHARE_DIR,mount_tag=hostshare,security_model=mapped,id=hostshare"
    )
fi

# Add debug flags if requested
if [ "$DEBUG" -eq 1 ]; then
    QEMU_ARGS+=(-s -S)
fi

# --- Print Info ---
echo "=============================================================================="
echo "  AArch64 Kernel Lab"
echo "=============================================================================="
echo ""
echo "  Kernel:     $KERNEL"
echo "  Image:      $RUNTIME_IMAGE"
echo "  Memory:     $MEMORY"
echo "  CPUs:       $CPUS"
echo ""
echo "  Login:      root / root"
echo "  SSH:        ssh -p 10022 root@localhost"

if [ "$SHARED" -eq 1 ]; then
    echo "  Shared:     $SHARE_DIR -> /mnt (run 'mount-shared' in guest)"
fi

if [ "$DEBUG" -eq 1 ]; then
    echo ""
    echo "  GDB:        Waiting for debugger on port 1234"
    echo "              Run './debug.sh' in another terminal"
fi

echo ""
echo "  Exit QEMU:  Ctrl-a x"
echo "=============================================================================="
echo ""

# --- Launch ---
exec qemu-system-aarch64 "${QEMU_ARGS[@]}"
