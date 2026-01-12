# Building the Linux Kernel

This guide covers downloading, configuring, and building the Linux 6.6 kernel for AArch64.

## Quick Build

```bash
make kernel
```

This script handles everything automatically.

## Manual Build Process

### 1. Download Kernel Source

```bash
git clone --depth 1 --branch v6.6 \
    https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
    linux-6.6
cd linux-6.6
```

### 2. Set Cross-Compilation Environment

```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
```

### 3. Generate Default Config

```bash
make defconfig
```

### 4. Enable Debug Options

The setup script enables these automatically, but for reference:

```bash
# Debug symbols for GDB
./scripts/config --enable CONFIG_DEBUG_INFO
./scripts/config --enable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
./scripts/config --enable CONFIG_GDB_SCRIPTS

# KGDB support
./scripts/config --enable CONFIG_KGDB
./scripts/config --enable CONFIG_KGDB_SERIAL_CONSOLE

# Disable KASLR (easier debugging)
./scripts/config --disable CONFIG_RANDOMIZE_BASE

# Frame pointers (better stack traces)
./scripts/config --enable CONFIG_FRAME_POINTER

# Loadable module support
./scripts/config --enable CONFIG_MODULES
./scripts/config --enable CONFIG_MODULE_UNLOAD

# 9P filesystem (shared folders)
./scripts/config --enable CONFIG_NET_9P
./scripts/config --enable CONFIG_NET_9P_VIRTIO
./scripts/config --enable CONFIG_9P_FS
```

### 5. Sync Configuration

```bash
make olddefconfig
```

### 6. Build

```bash
make -j$(nproc) Image vmlinux modules
```

Build outputs:
- `arch/arm64/boot/Image` - Kernel image for QEMU
- `vmlinux` - Kernel with debug symbols for GDB
- `modules/` - Loadable kernel modules

## Interactive Configuration

```bash
make menuconfig
```

Navigate with arrow keys, space to toggle, Enter to select.

### Recommended Options for Learning

```
General setup --->
    [*] Initial RAM filesystem and RAM disk support

Kernel hacking --->
    [*] Kernel debugging
    Compile-time checks and compiler options --->
        [*] Compile the kernel with debug info
        [*] Provide GDB scripts for kernel debugging
    Generic Kernel Debugging Instruments --->
        [*] KGDB: kernel debugger
            [*] KGDB: use kgdb over the serial console
    Memory Debugging --->
        [ ] KASAN: runtime memory debugger (optional, slows boot)

File systems --->
    [*] Network File Systems --->
        [*] Plan 9 Resource Sharing Support (9P2000)
        [*]   9P Virtio Transport
```

## Build Targets

| Target | Description |
|--------|-------------|
| `make Image` | Build kernel image only |
| `make vmlinux` | Build kernel with debug symbols |
| `make modules` | Build loadable modules |
| `make dtbs` | Build device tree blobs |
| `make -j$(nproc)` | Parallel build using all CPUs |

## Cleaning

```bash
# Clean build artifacts (keep config)
make clean

# Clean everything including config
make mrproper

# Remove editor backups, patches, etc.
make distclean
```

## Rebuilding After Changes

```bash
# After modifying source
make -j$(nproc)

# After config changes
make olddefconfig
make -j$(nproc)
```

## Installing Modules to Rootfs

Modules are installed to the rootfs during `make rootfs`. To update manually:

```bash
# Mount the rootfs
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 debian-rootfs.qcow2
sudo mount /dev/nbd0 /mnt

# Install modules
sudo make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    INSTALL_MOD_PATH=/mnt modules_install

# Cleanup
sudo umount /mnt
sudo qemu-nbd --disconnect /dev/nbd0
```

## Kernel Version

Check built kernel version:

```bash
file arch/arm64/boot/Image
# Output: Linux kernel ARM64 boot executable Image, little-endian, 4K pages
```

Inside the guest:

```bash
uname -r
# Output: 6.6.0
```

## Common Build Errors

### Missing Dependencies

```
fatal error: openssl/opensslv.h: No such file or directory
```

Fix: `sudo apt install libssl-dev`

### Missing flex/bison

```
/bin/sh: flex: command not found
```

Fix: `sudo apt install flex bison`

### Out of Memory

```
gcc: fatal error: Killed signal terminated program
```

Fix: Add swap or reduce parallel jobs: `make -j2`

## Cross-Compilation Reference

The `config.mk` file defines:

```makefile
ARCH := arm64
CROSS_COMPILE := aarch64-linux-gnu-
KDIR := ./linux-6.6
```

All kernel and module builds use these settings.

## Next Steps

- [03-rootfs.md](03-rootfs.md) - Creating the Debian rootfs
- [04-debugging.md](04-debugging.md) - Debugging the kernel with GDB
- [05-modules.md](05-modules.md) - Writing kernel modules
