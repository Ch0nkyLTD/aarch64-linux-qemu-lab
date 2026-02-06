# Promote Module + User-space Client
#
# Builds:
#   - promote.ko       (kernel module, via module.mk)
#   - promote_client    (user-space CLI, cross-compiled)
#   - Copies setup_user.sh to shared/
#
# The 'all' target builds both. The 'install' target copies everything.

MODULE_NAME := promote

# Include shared module build rules (builds the .ko)
include ../module.mk

# Cross-compiler for user-space client
CLIENT_CC := aarch64-linux-gnu-gcc
CLIENT_SRC := promote_client.c
CLIENT_BIN := $(BIN_DIR)/promote_client

# Override 'all' to also build the client
all: client

client: $(CLIENT_BIN)

$(CLIENT_BIN): $(CLIENT_SRC)
	@mkdir -p $(BIN_DIR)
	@echo "=== Building promote_client (aarch64, static) ==="
	$(CLIENT_CC) -Wall -static -o $(CLIENT_BIN) $(CLIENT_SRC)
	@echo "=== Success: $(CLIENT_BIN) ==="

# Override 'install' to also copy the client and setup script
install: all
	@mkdir -p $(LAB_ROOT)/shared/modules
	@cp $(BIN_DIR)/$(MODULE_NAME).ko $(LAB_ROOT)/shared/modules/
	@cp $(CLIENT_BIN) $(LAB_ROOT)/shared/modules/
	@cp setup_user.sh $(LAB_ROOT)/shared/modules/
	@echo "=== Installed .ko, promote_client, and setup_user.sh ==="

# Override 'clean' to also remove client
clean:
	@echo "=== Cleaning $(MODULE_NAME) ==="
	@rm -rf $(BUILD_DIR) $(BIN_DIR)

.PHONY: client
