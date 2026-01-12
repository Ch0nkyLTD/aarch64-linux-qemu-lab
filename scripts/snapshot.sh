#!/bin/bash

# ==============================================================================
# AArch64 Lab - Snapshot Manager
# ==============================================================================
# Creates and manages QCOW2 snapshots of the runtime image.
#
# Usage:
#   ./scripts/snapshot.sh create <name>    - Create a new snapshot
#   ./scripts/snapshot.sh list             - List all snapshots
#   ./scripts/snapshot.sh delete <name>    - Delete a snapshot
#   ./scripts/snapshot.sh info             - Show image info
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
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  create <name>   Create a snapshot with the given name"
    echo "  list            List all snapshots"
    echo "  delete <name>   Delete a snapshot"
    echo "  info            Show detailed image information"
    echo ""
    echo "Examples:"
    echo "  $0 create before-experiment"
    echo "  $0 list"
    echo "  $0 delete before-experiment"
}

check_image() {
    if [ ! -f "$RUNTIME_IMAGE" ]; then
        echo -e "${RED}Error: Runtime image not found: $RUNTIME_IMAGE${NC}"
        echo "Run 'make reset' first to create a runtime image."
        exit 1
    fi
}

cmd_create() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Snapshot name required${NC}"
        echo "Usage: $0 create <name>"
        exit 1
    fi

    check_image

    echo ">>> Creating snapshot '$name'..."
    qemu-img snapshot -c "$name" "$RUNTIME_IMAGE"
    echo -e "${GREEN}>>> Snapshot '$name' created successfully.${NC}"
}

cmd_list() {
    check_image

    echo ">>> Snapshots in $RUNTIME_IMAGE:"
    echo ""
    qemu-img snapshot -l "$RUNTIME_IMAGE" || echo "  (no snapshots)"
}

cmd_delete() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Snapshot name required${NC}"
        echo "Usage: $0 delete <name>"
        exit 1
    fi

    check_image

    echo ">>> Deleting snapshot '$name'..."
    qemu-img snapshot -d "$name" "$RUNTIME_IMAGE"
    echo -e "${GREEN}>>> Snapshot '$name' deleted.${NC}"
}

cmd_info() {
    check_image

    echo ">>> Image information:"
    echo ""
    qemu-img info "$RUNTIME_IMAGE"
}

# --- Main ---
case "${1:-}" in
    create)
        cmd_create "$2"
        ;;
    list)
        cmd_list
        ;;
    delete)
        cmd_delete "$2"
        ;;
    info)
        cmd_info
        ;;
    *)
        usage
        exit 1
        ;;
esac
