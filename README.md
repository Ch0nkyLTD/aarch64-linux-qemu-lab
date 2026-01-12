# AArch64 Kernel Development Lab

A complete environment for Linux kernel development and debugging on ARM64 (AArch64) using QEMU emulation. This lab provides infrastructure to build, run, and debug a custom Linux 6.6 kernel on a simulated Cortex-A57 system with a full Debian 12 (Bookworm) rootfs.

## Quick Start

```bash
# 1. Install dependencies
make deps

# 2. Build the kernel
make kernel

# 3. Create Debian rootfs (requires sudo)
make rootfs

# 4. Start the VM
make run
```

---

## Directory Structure

```
aarch64-lab/
├── setup/                  # Setup scripts
│   ├── setup_kernel.sh     # Download and build Linux kernel
│   └── setup_debian.sh     # Create Debian rootfs
├── scripts/                # Runtime scripts
│   ├── start.sh            # QEMU launcher (various modes)
│   ├── snapshot.sh         # Create/list/delete snapshots
│   └── restore.sh          # Restore snapshots or reset
├── modules/                # Custom kernel modules
│   ├── hello/              # Simple hello world module
│   └── secret/             # Syscall hooking example
├── shared/                 # Shared folder with guest VM
├── linux-6.6/              # Linux kernel source (after setup)
├── Makefile                # Main build interface
├── config.mk               # Cross-compilation settings
└── .gdbinit                # GDB configuration
```

---

## Makefile Targets

### Setup

| Target | Description |
|--------|-------------|
| `make deps` | Install all build dependencies |
| `make kernel` | Download and build Linux 6.6 |
| `make rootfs` | Create Debian rootfs (requires sudo) |
| `make all` | Run deps, kernel, and rootfs |

### Running the VM

| Target | Description |
|--------|-------------|
| `make run` | Start VM in debug mode (GDB on port 1234) |
| `make shared` | Start VM with shared folder + debug mode |
| `make nodebug` | Start VM immediately (no GDB pause) |
| `make debug` | Launch GDB and connect to running VM |
| `make ssh` | SSH into running VM |

### Snapshots

| Target | Description |
|--------|-------------|
| `make snapshot NAME=foo` | Create snapshot named "foo" |
| `make restore NAME=foo` | Restore to snapshot "foo" |
| `make snapshots` | List all snapshots |
| `make reset` | Reset to golden image (discard all changes) |

### Modules

| Target | Description |
|--------|-------------|
| `make modules` | Build all kernel modules |
| `make modules-install` | Build and copy to shared/modules/ |
| `make modules-clean` | Clean module builds |
| `make new-module NAME=x` | Create new module from template |
| `make module-hello` | Build a specific module |

---

## Step-by-Step Setup

### 1. Install Dependencies

```bash
make deps
```

This installs:
- QEMU system emulators
- AArch64 cross-compilation toolchain
- GDB with multiarch support
- Kernel build tools
- Debootstrap for rootfs creation

### 2. Build the Kernel

```bash
make kernel
```

This script:
- Downloads Linux 6.6 source
- Enables debug-friendly kernel options:
  - `CONFIG_DEBUG_INFO` - Debug symbols for GDB
  - `CONFIG_GDB_SCRIPTS` - GDB helper scripts
  - `CONFIG_KGDB` - Kernel debugger support
  - `CONFIG_9P_FS` - Shared folder support
  - Disables KASLR for easier debugging
- Builds kernel Image, vmlinux, and modules

### 3. Create Debian Rootfs

```bash
make rootfs   # Requires sudo
```

Creates a Debian 12 (Bookworm) ARM64 rootfs with pre-installed tools:

**Development:**
- gcc, g++, make, build-essential
- gdb, strace, ltrace

**Editors:**
- vim, nano

**Networking:**
- openssh-server (SSH enabled)
- curl, wget
- iproute2, net-tools

**Utilities:**
- htop, procps
- tree, file, less

---

## Image Architecture

The lab uses a layered QCOW2 architecture for fast reset:

```
Layer 1: debian-rootfs-base.img (raw)
    └── Base Debian OS from debootstrap

Layer 2: debian-rootfs.qcow2 (qcow2, backed by Layer 1)
    └── Golden image with config + kernel modules

Layer 3: debian-runtime.qcow2 (qcow2, backed by Layer 2)
    └── Disposable runtime for experiments
```

Benefits:
- Changes only stored in Layer 3
- Fast reset to clean state (`make reset`)
- Snapshots within Layer 3 (`make snapshot`)
- Base image never modified

---

## Running the Lab

### Basic Debug Mode

```bash
make run
```

VM starts paused, waiting for GDB. In another terminal:

```bash
make debug
```

### With Shared Folder

```bash
make shared
```

Inside the guest:
```bash
mount-shared        # Mounts host's ./shared at /mnt
# or manually:
mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt
```

### SSH Access

From host (while VM is running):
```bash
make ssh
# or:
ssh -p 10022 root@localhost
```

### Exit QEMU

Press `Ctrl-a x`

---

## Snapshots and Reset

### Create a Snapshot

Before making experimental changes:
```bash
make snapshot NAME=before-experiment
```

### List Snapshots

```bash
make snapshots
```

### Restore to Snapshot

```bash
make restore NAME=before-experiment
```

### Full Reset

Discard all changes and return to golden image:
```bash
make reset
```

---

## Kernel Module Development

### Creating a New Module

```bash
make new-module NAME=mydriver
```

This creates `modules/mydriver/` with a template `.c` file and Makefile.

### Building Modules

```bash
# Build all modules
make modules

# Build specific module
make module-hello

# Build and install to shared folder
make modules-install
```

### Module Makefile (Minimal)

Each module just needs a 2-line Makefile:

```makefile
# modules/mydriver/Makefile
include ../module.mk
```

The module name is auto-detected from the directory name.

### Loading Modules in Guest

```bash
# Build and install on host
make modules-install

# In guest: mount shared folder and load
mount-shared
insmod /mnt/modules/hello.ko
dmesg | tail
rmmod hello
```

### Example Modules

**hello/** - Basic module template:
```c
static int __init hello_init(void) {
    pr_info("Hello, AArch64!\n");
    return 0;
}
```

**secret/** - Syscall hooking with kprobes:
- Hooks `openat` syscall
- Blocks access to paths containing "secret"
- Toggle via sysfs parameter

### Module Directory Structure

```
modules/
├── module.mk           # Common build rules (included by all modules)
├── _template/          # Template for new modules
├── hello/
│   ├── Makefile        # Just: include ../module.mk
│   └── hello.c
└── secret/
    ├── Makefile
    └── secret.c
```

---

## GDB Kernel Debugging

### Quick Start

Terminal 1:
```bash
make run        # VM starts paused
```

Terminal 2:
```bash
make debug      # GDB connects and hits start_kernel
```

### Useful GDB Commands

```gdb
# Kernel helpers (from vmlinux-gdb.py)
lx-lsmod                    # List loaded modules
lx-dmesg                    # Show kernel log
p $lx_current()             # Current task struct

# Standard debugging
break do_sys_open           # Set breakpoint
bt                          # Backtrace
info threads                # List kernel threads
continue                    # Resume execution
```

### Manual GDB Connection

```bash
gdb-multiarch linux-6.6/vmlinux
(gdb) target remote :1234
(gdb) break start_kernel
(gdb) continue
```

---

## Credentials

| Type | Value |
|------|-------|
| Root password | `root` |
| SSH port | `10022` (localhost) |
| GDB port | `1234` |

---

## Troubleshooting

### Kernel panic - VFS unable to mount root

- Ensure rootfs was created: `ls -la debian-rootfs.qcow2`
- Rebuild: `make rootfs`

### GDB can't find symbols

- Use `vmlinux` not `Image` for symbols
- Ensure `CONFIG_DEBUG_INFO=y` in kernel config

### Shared folder mount fails

- Kernel must have `CONFIG_9P_FS=y` (setup_kernel.sh enables this)
- Use exact command: `mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt`

### SSH connection refused

- Wait for VM to fully boot
- Check SSH is running in guest: `systemctl status ssh`

---

## Cross-Compilation Reference

Environment variables (from `config.mk`):

```makefile
ARCH := arm64
CROSS_COMPILE := aarch64-linux-gnu-
KDIR := ./linux-6.6
```

Compile userspace program:
```bash
aarch64-linux-gnu-gcc -o hello hello.c
```

---

## File Reference

| File | Purpose |
|------|---------|
| `Makefile` | Main build interface |
| `setup/setup_kernel.sh` | Build Linux kernel |
| `setup/setup_debian.sh` | Create Debian rootfs |
| `scripts/start.sh` | QEMU launcher |
| `scripts/snapshot.sh` | Snapshot management |
| `scripts/restore.sh` | Restore/reset |
| `config.mk` | Cross-compile settings |
| `.gdbinit` | GDB initialization |

---

## License

This lab environment is for educational purposes.
Linux kernel is licensed under GPL v2.
