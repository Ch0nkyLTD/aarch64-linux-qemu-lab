#!/bin/bash

# ==============================================================================
# AArch64 Lab - Restore Manager
# ==============================================================================
# Restores the runtime image to a previous snapshot or resets to golden image.
#
# Usage:
#   ./scripts/restore.sh <name>    - Restore to a named snapshot
#   ./scripts/restore.sh --reset   - Reset to golden image (discard all changes)
#   ./scripts/restore.sh --list    - List available snapshots
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(dirname "$SCRIPT_DIR")"
RUNTIME_IMAGE="$LAB_ROOT/debian-runtime.qcow2"
GOLDEN_IMAGE="$LAB_ROOT/debian-rootfs.qcow2"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <snapshot-name> | --reset | --list"
    echo ""
    echo "Options:"
    echo "  <name>    Restore to a named snapshot"
    echo "  --reset   Reset to golden image (discard ALL changes)"
    echo "  --list    List available snapshots"
    echo ""
    echo "Examples:"
    echo "  $0 before-experiment     # Restore to snapshot"
    echo "  $0 --reset               # Full reset to golden image"
}

check_runtime() {
    if [ ! -f "$RUNTIME_IMAGE" ]; then
        echo -e "${RED}Error: Runtime image not found: $RUNTIME_IMAGE${NC}"
        echo "Run 'make reset' first to create a runtime image."
        exit 1
    fi
}

check_golden() {
    if [ ! -f "$GOLDEN_IMAGE" ]; then
        echo -e "${RED}Error: Golden image not found: $GOLDEN_IMAGE${NC}"
        echo "Run 'sudo ./setup/setup_debian.sh' first."
        exit 1
    fi
}

cmd_restore() {
    local name="$1"
    check_runtime

    echo ">>> Restoring to snapshot '$name'..."
    qemu-img snapshot -a "$name" "$RUNTIME_IMAGE"
    echo -e "${GREEN}>>> Restored to snapshot '$name'.${NC}"
}

cmd_reset() {
    check_golden

    echo -e "${YELLOW}>>> WARNING: This will discard ALL changes to the runtime image!${NC}"
    read -p "    Continue? [y/N] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "    Aborted."
        exit 0
    fi

    echo ">>> Resetting runtime environment..."

    # Delete old runtime image
    if [ -f "$RUNTIME_IMAGE" ]; then
        rm "$RUNTIME_IMAGE"
    fi

    # Create new runtime image backed by golden image
    qemu-img create -f qcow2 -F qcow2 -b "$(basename "$GOLDEN_IMAGE")" "$RUNTIME_IMAGE" > /dev/null

    echo -e "${GREEN}>>> Runtime image reset to golden state.${NC}"
    echo "    New disposable image: $RUNTIME_IMAGE"
}

cmd_list() {
    check_runtime

    echo ">>> Available snapshots:"
    echo ""
    qemu-img snapshot -l "$RUNTIME_IMAGE" || echo "  (no snapshots)"
}

# --- Main ---
case "${1:-}" in
    --reset)
        cmd_reset
        ;;
    --list)
        cmd_list
        ;;
    --help|-h)
        usage
        ;;
    "")
        usage
        exit 1
        ;;
    *)
        cmd_restore "$1"
        ;;
esac
