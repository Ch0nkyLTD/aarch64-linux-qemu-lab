# Kernel Module Development

This guide covers writing, building, and debugging loadable kernel modules (LKMs).

## Quick Start

```bash
# Create new module
make new-module NAME=mydriver

# Edit source
vim modules/mydriver/mydriver.c

# Build
make module-mydriver

# Install to shared folder
make modules-install

# In guest: load module
mount-shared
insmod /mnt/modules/mydriver.ko
```

## Creating a New Module

```bash
make new-module NAME=mydriver
```

Creates:
```
modules/mydriver/
├── Makefile      # Build configuration
└── mydriver.c    # Module source
```

## Module Template

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Module description");
MODULE_VERSION("1.0");

// Module parameter
static int param_value = 42;
module_param(param_value, int, 0644);
MODULE_PARM_DESC(param_value, "An example parameter");

// Called when module loads
static int __init mydriver_init(void)
{
    pr_info("mydriver: loaded, param=%d\n", param_value);
    return 0;  // 0 = success
}

// Called when module unloads
static void __exit mydriver_exit(void)
{
    pr_info("mydriver: unloaded\n");
}

module_init(mydriver_init);
module_exit(mydriver_exit);
```

## Module Makefile

Each module needs only a 2-line Makefile:

```makefile
# modules/mydriver/Makefile
include ../module.mk
```

The `module.mk` handles:
- Cross-compilation setup
- Kernel build system invocation
- Output to `bin/` directory
- Install target for shared folder

## Building Modules

```bash
# Build all modules
make modules

# Build specific module
make module-mydriver

# Build and install to shared/modules/
make modules-install

# Clean all modules
make modules-clean
```

## Loading Modules

### In Guest VM

```bash
# Mount shared folder first
mount-shared

# Load module
insmod /mnt/modules/mydriver.ko

# Load with parameters
insmod /mnt/modules/mydriver.ko param_value=100

# Check if loaded
lsmod | grep mydriver

# View kernel messages
dmesg | tail

# Unload module
rmmod mydriver
```

### Module Parameters

```bash
# Set at load time
insmod mydriver.ko param_value=100

# View current values
cat /sys/module/mydriver/parameters/param_value

# Change at runtime (if permissions allow)
echo 200 > /sys/module/mydriver/parameters/param_value
```

## Kernel APIs

### Printing

```c
pr_info("Info message\n");
pr_warn("Warning message\n");
pr_err("Error message\n");
pr_debug("Debug message\n");  // Needs CONFIG_DYNAMIC_DEBUG

// With device context
dev_info(dev, "Device message\n");

// Old style (avoid)
printk(KERN_INFO "Message\n");
```

### Memory Allocation

```c
#include <linux/slab.h>

// Allocate
void *ptr = kmalloc(size, GFP_KERNEL);
void *ptr = kzalloc(size, GFP_KERNEL);  // Zero-initialized
void *ptr = vmalloc(large_size);         // For large allocations

// Free
kfree(ptr);
vfree(ptr);
```

### Synchronization

```c
#include <linux/mutex.h>
#include <linux/spinlock.h>

// Mutex (can sleep)
DEFINE_MUTEX(my_mutex);
mutex_lock(&my_mutex);
mutex_unlock(&my_mutex);

// Spinlock (cannot sleep)
DEFINE_SPINLOCK(my_lock);
spin_lock(&my_lock);
spin_unlock(&my_lock);
```

### Work Queues

```c
#include <linux/workqueue.h>

void my_work_handler(struct work_struct *work)
{
    // Do work
}

DECLARE_WORK(my_work, my_work_handler);

// Schedule work
schedule_work(&my_work);
```

### Timers

```c
#include <linux/timer.h>

struct timer_list my_timer;

void timer_callback(struct timer_list *timer)
{
    pr_info("Timer fired!\n");
    mod_timer(timer, jiffies + HZ);  // Reschedule in 1 second
}

// In init
timer_setup(&my_timer, timer_callback, 0);
mod_timer(&my_timer, jiffies + HZ);

// In exit
del_timer_sync(&my_timer);
```

## Character Device Example

```c
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>

static int major;
static struct class *cls;

static int dev_open(struct inode *inode, struct file *file)
{
    pr_info("Device opened\n");
    return 0;
}

static ssize_t dev_read(struct file *file, char __user *buf,
                        size_t len, loff_t *offset)
{
    char msg[] = "Hello from kernel\n";
    size_t msg_len = sizeof(msg);

    if (*offset >= msg_len)
        return 0;

    if (copy_to_user(buf, msg, msg_len))
        return -EFAULT;

    *offset += msg_len;
    return msg_len;
}

static struct file_operations fops = {
    .owner = THIS_MODULE,
    .open = dev_open,
    .read = dev_read,
};

static int __init chardev_init(void)
{
    major = register_chrdev(0, "mychardev", &fops);
    cls = class_create("mychardev");
    device_create(cls, NULL, MKDEV(major, 0), NULL, "mychardev");
    pr_info("Device: /dev/mychardev\n");
    return 0;
}

static void __exit chardev_exit(void)
{
    device_destroy(cls, MKDEV(major, 0));
    class_destroy(cls);
    unregister_chrdev(major, "mychardev");
}

module_init(chardev_init);
module_exit(chardev_exit);
```

## Kprobe Example (Syscall Hooking)

See `modules/secret/` for a complete example.

```c
#include <linux/kprobes.h>

static struct kprobe kp = {
    .symbol_name = "do_sys_openat2",
};

static int handler_pre(struct kprobe *p, struct pt_regs *regs)
{
    // Called before function executes
    pr_info("Opening file...\n");
    return 0;
}

static void handler_post(struct kprobe *p, struct pt_regs *regs,
                         unsigned long flags)
{
    // Called after function returns
}

static int __init kprobe_init(void)
{
    kp.pre_handler = handler_pre;
    kp.post_handler = handler_post;
    register_kprobe(&kp);
    return 0;
}

static void __exit kprobe_exit(void)
{
    unregister_kprobe(&kp);
}
```

## Debugging Modules

### Using printk

```c
pr_info("Value: %d, pointer: %px\n", val, ptr);
```

View output:
```bash
dmesg -w        # Watch live
dmesg | tail    # Recent messages
```

### Using GDB

1. Load module in guest
2. In GDB:

```gdb
# Load symbols for all modules
lx-symbols

# Or manually (get address from /proc/modules)
add-symbol-file modules/mydriver/bin/mydriver.ko 0xffff...

# Set breakpoint
break mydriver_init

# Reload module
```

### Using ftrace

```bash
# Enable function tracing
echo function > /sys/kernel/debug/tracing/current_tracer
echo mydriver_* > /sys/kernel/debug/tracing/set_ftrace_filter
cat /sys/kernel/debug/tracing/trace
```

## Common Errors

### Module Version Mismatch

```
module: version magic '6.6.0 SMP preempt mod_unload' should be...
```

Rebuild module against current kernel:
```bash
make modules-clean
make modules
```

### Unknown Symbol

```
Unknown symbol some_function
```

Check if required module is loaded or symbol is exported.

### GPL Symbol in Non-GPL Module

```
module: GPL-incompatible module uses GPL-only symbol
```

Add `MODULE_LICENSE("GPL");`

## Module Directory Layout

```
modules/
├── module.mk           # Common build rules
├── _template/          # Template for new modules
│   ├── Makefile
│   └── template.c
├── hello/              # Simple example
│   ├── Makefile
│   ├── hello.c
│   ├── build/          # Build artifacts
│   └── bin/            # Output .ko
└── secret/             # Kprobe example
    ├── Makefile
    ├── secret.c
    ├── build/
    └── bin/
```

## Next Steps

- [04-debugging.md](04-debugging.md) - GDB kernel debugging
- [06-snapshots.md](06-snapshots.md) - Save/restore VM state
- Study `modules/hello/` and `modules/secret/` examples
