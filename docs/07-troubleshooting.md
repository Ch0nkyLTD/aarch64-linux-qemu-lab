# Troubleshooting Guide

Common issues and solutions for the AArch64 Kernel Lab.

## Boot Issues

### Kernel Panic - VFS Unable to Mount Root

```
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

**Causes:**
- Rootfs image missing or corrupted
- Wrong root device in kernel command line
- Missing virtio drivers in kernel

**Solutions:**

```bash
# Check image exists
ls -la debian-rootfs.qcow2

# Rebuild rootfs
make reset
# or full rebuild:
rm debian-rootfs*.img debian-rootfs.qcow2
make rootfs

# Check kernel has virtio support
grep VIRTIO linux-6.6/.config | grep -E "BLK|NET"
# Should show: CONFIG_VIRTIO_BLK=y
```

### Kernel Hangs at Boot

**Causes:**
- Waiting for GDB (expected behavior with `make run`)
- Kernel crash before console init

**Solutions:**

```bash
# If using make run, connect GDB:
make debug

# Or boot without debug pause:
make nodebug

# Check for early crash - add earlyprintk
# Edit scripts/start.sh, add to -append:
# "earlyprintk=serial"
```

### No Console Output

**Causes:**
- Wrong console device
- Serial driver not enabled

**Solutions:**

```bash
# Check kernel config
grep SERIAL_AMBA linux-6.6/.config
# Should show: CONFIG_SERIAL_AMBA_PL011=y
# And: CONFIG_SERIAL_AMBA_PL011_CONSOLE=y

# Boot args should include:
# console=ttyAMA0
```

## Network Issues

### No Network in Guest

```bash
# Check interface exists
ip link
# Should show: enp0s1

# Check if up
ip addr show enp0s1

# Manual DHCP
dhclient enp0s1

# Check routing
ip route
```

**If interface missing:**

```bash
# Check kernel virtio-net
grep VIRTIO_NET linux-6.6/.config
# Should show: CONFIG_VIRTIO_NET=y
```

### SSH Connection Refused

```bash
# In guest, check SSH status
systemctl status ssh

# Start if not running
systemctl start ssh

# Check it's listening
ss -tlnp | grep 22
```

**From host:**

```bash
# Correct port is 10022
ssh -p 10022 root@localhost

# Debug connection
ssh -v -p 10022 root@localhost
```

### SSH Host Key Changed

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

**Solution:**

```bash
# Remove old key
ssh-keygen -R "[localhost]:10022"

# Or use the make target (ignores host key)
make ssh
```

## Shared Folder Issues

### Mount Fails: No Such Device

```
mount: /mnt: unknown filesystem type '9p'.
```

**Solution:** Kernel missing 9P support

```bash
# Check kernel config
grep 9P linux-6.6/.config

# Should show:
# CONFIG_NET_9P=y
# CONFIG_NET_9P_VIRTIO=y
# CONFIG_9P_FS=y

# Rebuild kernel if missing
cd linux-6.6
./scripts/config --enable CONFIG_NET_9P
./scripts/config --enable CONFIG_NET_9P_VIRTIO
./scripts/config --enable CONFIG_9P_FS
make olddefconfig
make -j$(nproc)
```

### Mount Fails: Permission Denied

```bash
# Use correct security model
mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt

# Or in guest:
mount-shared
```

### Shared Folder Empty

Check you started with `--shared`:

```bash
make shared
# Not just: make run
```

## GDB Issues

### Cannot Connect to Remote

```
(gdb) target remote :1234
:1234: Connection refused.
```

**Solutions:**

```bash
# Make sure QEMU is running with -s flag
# Use make run (not make nodebug)
make run

# Check port is listening
ss -tlnp | grep 1234
```

### Symbols Don't Match / Wrong Addresses

**Causes:**
- KASLR enabled
- Different kernel version
- vmlinux out of sync

**Solutions:**

```bash
# Ensure KASLR disabled
grep RANDOMIZE_BASE linux-6.6/.config
# Should show: CONFIG_RANDOMIZE_BASE is not set

# Boot args should include: nokaslr

# Rebuild kernel
cd linux-6.6
make -j$(nproc)
```

### GDB Hangs / No Response

```bash
# In GDB, press Ctrl+C to interrupt

# If VM crashed, restart:
# Terminal 1:
make run
# Terminal 2:
make debug
```

### "Remote connection closed"

QEMU terminated unexpectedly.

```bash
# Check QEMU output for crash reason
# Restart:
make run
```

## Module Issues

### Version Magic Mismatch

```
module: version magic '6.6.0 SMP preempt' should be '6.6.0-custom'
```

**Solution:** Rebuild module against current kernel

```bash
make modules-clean
make modules
```

### Unknown Symbol

```
mymodule: Unknown symbol some_function (err -2)
```

**Causes:**
- Required module not loaded
- Symbol not exported
- Wrong kernel version

**Solutions:**

```bash
# Check if symbol is exported
grep some_function linux-6.6/Module.symvers

# Load dependent module first
modprobe required_module
insmod mymodule.ko
```

### Module Not Found

```bash
# Check module built successfully
ls modules/mydriver/bin/
# Should show: mydriver.ko

# Rebuild if missing
make module-mydriver
```

### Insmod: Operation Not Permitted

In guest:
```bash
# Must be root
sudo insmod module.ko

# Or check module signing
grep MODULE_SIG linux-6.6/.config
# If enabled, disable it for lab use
```

## Build Issues

### Cross-Compiler Not Found

```
aarch64-linux-gnu-gcc: command not found
```

**Solution:**

```bash
make deps
# or
sudo apt install gcc-aarch64-linux-gnu
```

### Kernel Build Fails

```bash
# Check dependencies
make deps

# Common missing packages
sudo apt install libssl-dev libelf-dev flex bison

# Clean and rebuild
cd linux-6.6
make clean
make -j$(nproc)
```

### Out of Memory During Build

```
gcc: fatal error: Killed signal terminated program
```

**Solution:** Reduce parallel jobs

```bash
# Instead of -j$(nproc), use fewer jobs
make -j2
```

## QEMU Issues

### QEMU Not Found

```bash
sudo apt install qemu-system-aarch64
```

### QEMU Crashes

Check for:
- Corrupt image: `qemu-img check debian-runtime.qcow2`
- Missing files: Ensure kernel and rootfs exist
- Memory: Try reducing `-m 1G`

### Exit QEMU

- `Ctrl-a x` - Kill QEMU
- `Ctrl-a c` - Enter monitor, then `quit`
- In guest: `poweroff`

## Rootfs Issues

### Debootstrap Fails

```bash
# Check network
ping deb.debian.org

# Try different mirror
# Edit setup/setup_debian.sh:
# http://ftp.us.debian.org/debian/
```

### NBD Device Busy

```bash
# Disconnect all NBD
sudo qemu-nbd --disconnect /dev/nbd0
sudo rmmod nbd

# Reload
sudo modprobe nbd max_part=8
```

### No Space in Rootfs

```bash
# Check inside guest
df -h

# Resize image (complex, easier to rebuild)
rm debian-rootfs-base.img debian-rootfs.qcow2
# Increase IMAGE_SIZE in setup/setup_debian.sh
make rootfs
```

## Reset Everything

When all else fails:

```bash
# Full clean rebuild
make distclean
rm -rf linux-6.6

# Rebuild everything
make all
```

## Getting Help

1. Check kernel messages: `dmesg | tail`
2. Check boot messages: Watch QEMU output during boot
3. Check QEMU monitor: `Ctrl-a c`, then `info` commands
4. Enable verbose boot: Add `debug` to kernel command line

## Quick Fixes Reference

| Problem | Quick Fix |
|---------|-----------|
| Can't boot | `make reset` |
| Can't connect GDB | Restart with `make run` |
| Module won't load | `make modules-clean && make modules` |
| SSH fails | `make ssh` (ignores host key) |
| Network down | `dhclient enp0s1` in guest |
| Shared folder empty | Use `make shared` not `make run` |
| Image corrupted | `make reset` |
| Everything broken | `make distclean && make all` |
