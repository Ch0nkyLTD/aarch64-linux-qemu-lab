# Allow GDB to load scripts from the linux build directory
set auto-load safe-path /

# Connect to the remote QEMU target
target remote :1234

# Load the kernel symbols
file linux-6.6/vmlinux

# Load the Linux Kernel GDB helpers
source linux-6.6/vmlinux-gdb.py

# Set a breakpoint at the start of the kernel (optional)
break start_kernel

# Resume execution
continue
