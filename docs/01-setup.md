# Setup Guide

This guide covers the initial setup of the AArch64 Kernel Development Lab.

## Prerequisites

- Ubuntu/Debian-based host system (x86_64)
- At least 10GB free disk space
- sudo access for rootfs creation
- Internet connection for downloading packages and kernel source

## Quick Setup

```bash
# Complete setup in one command
make all
```

This runs `deps`, `kernel`, and `rootfs` in sequence.

## Step-by-Step Setup

### 1. Install Dependencies

```bash
make deps
```

This installs:

| Package | Purpose |
|---------|---------|
| `qemu-system-aarch64` | ARM64 system emulator |
| `gcc-aarch64-linux-gnu` | Cross-compiler |
| `g++-aarch64-linux-gnu` | C++ cross-compiler |
| `gdb-multiarch` | Debugger with ARM64 support |
| `build-essential` | Basic build tools |
| `bison`, `flex` | Parser generators for kernel |
| `libncurses-dev` | For `make menuconfig` |
| `libssl-dev` | Kernel crypto support |
| `libelf-dev` | ELF file handling |
| `debootstrap` | Debian rootfs builder |
| `qemu-user-static` | User-mode QEMU for chroot |
| `qemu-utils` | QEMU image tools |

### 2. Build the Kernel

```bash
make kernel
```

See [02-kernel.md](02-kernel.md) for details.

### 3. Create Debian Rootfs

```bash
make rootfs   # Requires sudo
```

See [03-rootfs.md](03-rootfs.md) for details.

## Verifying Setup

After setup, you should have:

```
aarch64-lab/
├── linux-6.6/
│   ├── arch/arm64/boot/Image    # Kernel image
│   └── vmlinux                   # Debug symbols
├── debian-rootfs-base.img        # Base Debian image
└── debian-rootfs.qcow2           # Golden image
```

Verify with:

```bash
ls -lh linux-6.6/arch/arm64/boot/Image
ls -lh debian-rootfs.qcow2
```

## First Boot

```bash
# Start VM (pauses for debugger)
make run

# Or start immediately without debugger
make nodebug
```

Login: `root` / `root`

## Directory Structure After Setup

```
aarch64-lab/
├── setup/                  # Setup scripts
├── scripts/                # Runtime scripts
├── modules/                # Kernel modules
├── shared/                 # Host-guest shared folder
├── docs/                   # Documentation
├── linux-6.6/              # Kernel source
├── debian-rootfs-base.img  # Layer 1: Base OS
├── debian-rootfs.qcow2     # Layer 2: Golden image
├── debian-runtime.qcow2    # Layer 3: Runtime (created on first run)
├── Makefile
└── README.md
```

## Updating the Lab

### Update Kernel Only

```bash
cd linux-6.6
git pull
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
```

### Rebuild Rootfs

```bash
# Remove old images
rm debian-rootfs-base.img debian-rootfs.qcow2

# Rebuild
make rootfs
```

### Update Kernel Modules in Rootfs

After rebuilding the kernel with new modules:

```bash
# This rebuilds the golden image with new modules
sudo ./setup/setup_debian.sh
```

## Next Steps

- [02-kernel.md](02-kernel.md) - Kernel configuration and building
- [03-rootfs.md](03-rootfs.md) - Rootfs customization
- [04-debugging.md](04-debugging.md) - GDB kernel debugging
