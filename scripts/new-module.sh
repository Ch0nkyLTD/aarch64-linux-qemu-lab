#!/bin/bash

# ==============================================================================
# Create a New Kernel Module
# ==============================================================================
# Usage: ./scripts/new-module.sh <module_name>
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$LAB_ROOT/modules"
TEMPLATE_DIR="$MODULES_DIR/_template"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <module_name>"
    echo ""
    echo "Creates a new kernel module from template."
    echo ""
    echo "Example:"
    echo "  $0 mydriver"
    echo ""
    echo "This creates:"
    echo "  modules/mydriver/Makefile"
    echo "  modules/mydriver/mydriver.c"
}

if [ -z "$1" ]; then
    usage
    exit 1
fi

MODULE_NAME="$1"
MODULE_DIR="$MODULES_DIR/$MODULE_NAME"

# Validate module name (alphanumeric and underscore only)
if [[ ! "$MODULE_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo -e "${RED}Error: Invalid module name '$MODULE_NAME'${NC}"
    echo "Module name must start with a letter or underscore,"
    echo "and contain only letters, numbers, and underscores."
    exit 1
fi

# Check if module already exists
if [ -d "$MODULE_DIR" ]; then
    echo -e "${RED}Error: Module '$MODULE_NAME' already exists at $MODULE_DIR${NC}"
    exit 1
fi

# Create module directory
echo ">>> Creating module: $MODULE_NAME"
mkdir -p "$MODULE_DIR"

# Copy and customize Makefile
cp "$TEMPLATE_DIR/Makefile" "$MODULE_DIR/"

# Copy and rename template.c
sed -e "s/template/$MODULE_NAME/g" \
    -e "s/Template/${MODULE_NAME^}/g" \
    -e "s/TEMPLATE/${MODULE_NAME^^}/g" \
    "$TEMPLATE_DIR/template.c" > "$MODULE_DIR/$MODULE_NAME.c"

echo -e "${GREEN}>>> Module created: $MODULE_DIR${NC}"
echo ""
echo "Files:"
echo "  $MODULE_DIR/Makefile"
echo "  $MODULE_DIR/$MODULE_NAME.c"
echo ""
echo "Next steps:"
echo "  1. Edit $MODULE_DIR/$MODULE_NAME.c"
echo "  2. Build: make modules"
echo "  3. Or build just this module: cd modules/$MODULE_NAME && make"
