# AArch64 Kernel Lab Documentation

## Quick Start

```bash
make deps      # Install dependencies
make kernel    # Build Linux 6.6
make rootfs    # Create Debian rootfs (sudo)
make run       # Start VM
```

## Documentation Index

| Document | Description |
|----------|-------------|
| [01-setup.md](01-setup.md) | Initial setup and dependencies |
| [02-kernel.md](02-kernel.md) | Building and configuring the kernel |
| [03-rootfs.md](03-rootfs.md) | Debian rootfs creation and customization |
| [04-debugging.md](04-debugging.md) | GDB kernel debugging |
| [05-modules.md](05-modules.md) | Writing kernel modules |
| [06-snapshots.md](06-snapshots.md) | Snapshots and reset |
| [07-troubleshooting.md](07-troubleshooting.md) | Common issues and solutions |

## Common Commands

### Setup

```bash
make deps           # Install dependencies
make kernel         # Build kernel
make rootfs         # Create rootfs (sudo)
make all            # All of the above
```

### Running

```bash
make run            # Start with GDB (paused)
make shared         # Start with shared folder
make nodebug        # Start immediately
make debug          # Connect GDB
make ssh            # SSH into guest
```

### Snapshots

```bash
make snapshot NAME=foo    # Create snapshot
make restore NAME=foo     # Restore snapshot
make snapshots            # List snapshots
make reset                # Full reset
```

### Modules

```bash
make new-module NAME=foo  # Create new module
make modules              # Build all
make module-hello         # Build specific
make modules-install      # Copy to shared/
```

## Credentials

- **Login**: root / root
- **SSH**: `ssh -p 10022 root@localhost`
- **GDB**: Port 1234

## QEMU Controls

- `Ctrl-a x` - Exit QEMU
- `Ctrl-a c` - QEMU monitor
- `Ctrl-a ?` - Help

## Directory Structure

```
aarch64-lab/
├── setup/           # Setup scripts
├── scripts/         # Runtime scripts
├── modules/         # Kernel modules
├── shared/          # Host-guest shared folder
├── docs/            # This documentation
├── linux-6.6/       # Kernel source
└── Makefile         # Main interface
```
