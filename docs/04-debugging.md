# Kernel Debugging with GDB

This guide covers debugging the Linux kernel using GDB and QEMU's built-in GDB server.

## Quick Start

**Terminal 1** - Start VM (paused):
```bash
make run
```

**Terminal 2** - Connect GDB:
```bash
make debug
```

GDB connects and stops at `start_kernel`. Press `c` to continue.

## How It Works

1. QEMU starts with `-s -S` flags:
   - `-s`: Start GDB server on port 1234
   - `-S`: Pause CPU at startup (wait for debugger)

2. GDB connects and loads symbols from `vmlinux`

3. Kernel boot pauses at `start_kernel` breakpoint

## GDB Configuration

The `.gdbinit` file configures GDB automatically:

```gdb
set auto-load safe-path /
target remote :1234
file linux-6.6/vmlinux
source linux-6.6/scripts/gdb/vmlinux-gdb.py
break start_kernel
continue
```

## Basic GDB Commands

### Execution Control

| Command | Description |
|---------|-------------|
| `c` / `continue` | Continue execution |
| `s` / `step` | Step into function |
| `n` / `next` | Step over function |
| `finish` | Run until function returns |
| `Ctrl+C` | Pause execution |

### Breakpoints

| Command | Description |
|---------|-------------|
| `break <func>` | Break at function |
| `break <file>:<line>` | Break at line |
| `break *<addr>` | Break at address |
| `info breakpoints` | List breakpoints |
| `delete <num>` | Delete breakpoint |
| `disable <num>` | Disable breakpoint |

### Inspection

| Command | Description |
|---------|-------------|
| `bt` / `backtrace` | Show call stack |
| `frame <n>` | Select stack frame |
| `info registers` | Show CPU registers |
| `p <expr>` | Print expression |
| `x/<n><f> <addr>` | Examine memory |

### Examples

```gdb
# Break at system call
break do_sys_openat2

# Break at specific file:line
break fs/open.c:1234

# Print variable
p current->comm

# Print structure
p *current

# Examine memory (16 hex words)
x/16xw 0xffff800000000000

# Show registers
info registers
```

## Linux Kernel GDB Scripts

The kernel provides Python scripts that add kernel-aware commands.

### Enable Scripts

```gdb
source linux-6.6/scripts/gdb/vmlinux-gdb.py
```

### Kernel Commands

| Command | Description |
|---------|-------------|
| `lx-dmesg` | Show kernel log buffer |
| `lx-lsmod` | List loaded modules |
| `lx-ps` | List processes |
| `lx-symbols` | Load module symbols |
| `p $lx_current()` | Current task_struct |
| `p $lx_per_cpu("var", cpu)` | Per-CPU variable |

### Examples

```gdb
# Show kernel messages
lx-dmesg

# List modules
lx-lsmod

# Current process
p $lx_current()->comm
p $lx_current()->pid

# List all processes
lx-ps
```

## Debugging Scenarios

### Breaking at Boot

```gdb
# Already configured in .gdbinit
break start_kernel
continue
```

### Breaking at System Call

```gdb
# Open syscall
break do_sys_openat2
continue

# In guest, trigger with:
# cat /etc/passwd
```

### Breaking at Module Load

```gdb
break do_init_module
continue

# In guest:
# insmod /mnt/modules/hello.ko
```

### Debugging a Specific Module

```gdb
# After module is loaded, add its symbols
lx-symbols

# Or manually
add-symbol-file modules/hello/bin/hello.ko <address>

# Find address from /proc/modules in guest
```

### Breaking on Kernel Panic

```gdb
break panic
continue
```

### Catching Page Faults

```gdb
break do_page_fault
continue
```

## Examining Kernel Data Structures

### Current Process

```gdb
# Task name
p $lx_current()->comm

# PID
p $lx_current()->pid

# Process state
p $lx_current()->__state

# Memory descriptor
p *$lx_current()->mm
```

### Process List

```gdb
# Using kernel scripts
lx-ps

# Manual traversal
p init_task.tasks
```

### File Descriptors

```gdb
# Current process files
p $lx_current()->files->fdt->fd[0]
```

## Tips and Tricks

### Disable KASLR

Already disabled by kernel config and boot parameter `nokaslr`.
This ensures addresses match between `vmlinux` and runtime.

### Reload Symbols After Module Load

```gdb
lx-symbols
```

### Save Breakpoints

```gdb
save breakpoints bp.txt
# Later:
source bp.txt
```

### Conditional Breakpoints

```gdb
# Break only for specific process
break do_sys_openat2 if $lx_current()->pid == 123
```

### Watchpoints

```gdb
# Break when variable changes
watch some_global_var

# Break on memory access
awatch *0xffff800012345678
```

### Pretty Printing

```gdb
set print pretty on
p *current
```

## Common Issues

### "Remote connection closed"

QEMU crashed or was closed. Restart with `make run`.

### "Cannot access memory"

- Kernel hasn't booted far enough
- Address space changed (KASLR enabled?)
- Use `continue` to let kernel boot more

### Symbols Don't Match

Rebuild kernel and ensure using same `vmlinux`:

```bash
make -j$(nproc)
# Restart QEMU and GDB
```

### GDB Hangs

Press `Ctrl+C` to interrupt, then check VM state.

## Alternative: KGDB

For debugging without QEMU's GDB server (e.g., real hardware):

```bash
# Boot with kgdb parameters
console=ttyAMA0 kgdboc=ttyAMA0,115200 kgdbwait
```

## Remote Debugging Setup

For debugging from another machine:

```bash
# On QEMU host, expose GDB port
qemu-system-aarch64 ... -gdb tcp:0.0.0.0:1234

# From remote machine
gdb-multiarch vmlinux
(gdb) target remote <host>:1234
```

## Next Steps

- [05-modules.md](05-modules.md) - Debugging kernel modules
- [07-troubleshooting.md](07-troubleshooting.md) - Common issues
