# Debian Rootfs Guide

This guide covers creating and customizing the Debian ARM64 root filesystem.

## Quick Setup

```bash
make rootfs   # Requires sudo
```

## Image Architecture

The lab uses a layered QCOW2 architecture:

```
Layer 1: debian-rootfs-base.img (raw, ~2GB)
    └── Base Debian OS from debootstrap
    └── Installed packages (gcc, gdb, vim, ssh, etc.)

Layer 2: debian-rootfs.qcow2 (qcow2, backed by Layer 1)
    └── System configuration (hostname, network, users)
    └── Kernel modules from linux-6.6

Layer 3: debian-runtime.qcow2 (qcow2, backed by Layer 2)
    └── Your runtime experiments
    └── Disposable - reset anytime with 'make reset'
```

### Benefits

- **Fast reset**: `make reset` creates fresh Layer 3 instantly
- **Snapshots**: Save/restore points within Layer 3
- **Base preservation**: Layers 1-2 never modified during use
- **Space efficient**: Only changes are stored in upper layers

## What's Installed

### Development Tools

| Package | Description |
|---------|-------------|
| `build-essential` | gcc, g++, make |
| `gdb` | GNU Debugger |
| `strace` | System call tracer |
| `ltrace` | Library call tracer |

### Editors

| Package | Description |
|---------|-------------|
| `vim` | Vi improved |
| `nano` | Simple editor |
| `less` | Pager |

### Networking

| Package | Description |
|---------|-------------|
| `openssh-server` | SSH daemon (enabled) |
| `curl` | HTTP client |
| `wget` | File downloader |
| `iproute2` | `ip` command |
| `net-tools` | `ifconfig`, `netstat` |

### Utilities

| Package | Description |
|---------|-------------|
| `htop` | Interactive process viewer |
| `procps` | `ps`, `top`, `free` |
| `tree` | Directory tree |
| `file` | File type detection |
| `bash-completion` | Tab completion |

## System Configuration

### Credentials

- **Root password**: `root`
- **Hostname**: `aarch64-lab`

### Network

- DHCP on `enp0s1` (QEMU virtio-net)
- SSH enabled on port 22 (forwarded to host:10022)

### Filesystem

```
/dev/vda    /       ext4    defaults,noatime    0 1
```

## Customizing the Rootfs

### Adding Packages

Mount and chroot into the image:

```bash
# Load NBD module
sudo modprobe nbd max_part=8

# Connect image
sudo qemu-nbd --connect=/dev/nbd0 debian-rootfs.qcow2

# Mount
sudo mount /dev/nbd0 /mnt

# Chroot
sudo chroot /mnt /bin/bash

# Now inside the rootfs - install packages
apt update
apt install <package>

# Exit and cleanup
exit
sudo umount /mnt
sudo qemu-nbd --disconnect /dev/nbd0
```

### Adding Users

```bash
# Inside chroot
useradd -m -s /bin/bash student
echo "student:student" | chpasswd
```

### Custom Startup Scripts

Add to `/etc/rc.local` or create a systemd service.

## Rebuilding Rootfs

### Full Rebuild

```bash
# Remove all images
rm debian-rootfs-base.img debian-rootfs.qcow2 debian-runtime.qcow2

# Rebuild from scratch
make rootfs
```

### Rebuild Overlay Only

Keep the base image, rebuild configuration layer:

```bash
rm debian-rootfs.qcow2 debian-runtime.qcow2
sudo ./setup/setup_debian.sh
```

### Update Kernel Modules Only

```bash
# Rebuild kernel first
cd linux-6.6
make -j$(nproc) modules

# Then rebuild rootfs overlay
rm debian-rootfs.qcow2 debian-runtime.qcow2
sudo ./setup/setup_debian.sh
```

## Debootstrap Process

The setup script uses debootstrap in two stages:

### Stage 1: Download

```bash
debootstrap --arch=arm64 --foreign bookworm rootfs http://deb.debian.org/debian/
```

Downloads packages for ARM64 architecture.

### Stage 2: Configure

```bash
cp /usr/bin/qemu-aarch64-static rootfs/usr/bin/
chroot rootfs /debootstrap/debootstrap --second-stage
```

Configures packages using QEMU user-mode emulation.

## Shared Folder

The guest can access `./shared` on the host:

```bash
# In guest
mount-shared
# or
mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt

ls /mnt   # Shows contents of ./shared on host
```

## Troubleshooting

### Rootfs Won't Boot

Check kernel has virtio support:

```bash
grep VIRTIO linux-6.6/.config
# Should show CONFIG_VIRTIO_BLK=y
```

### SSH Connection Refused

Inside guest:

```bash
systemctl status ssh
systemctl start ssh
```

### Network Not Working

```bash
# Check interface
ip link

# Manual DHCP
dhclient enp0s1
```

### Shared Folder Mount Fails

Kernel needs 9P support:

```bash
grep 9P linux-6.6/.config
# Should show CONFIG_9P_FS=y
```

## Alternative: Minimal BusyBox Rootfs

For faster boot or minimal testing:

```bash
./deprecated/rootfs.sh
```

Creates a tiny initramfs with BusyBox. Useful for kernel-only testing.

## Next Steps

- [04-debugging.md](04-debugging.md) - Debugging the kernel
- [05-modules.md](05-modules.md) - Writing kernel modules
- [06-snapshots.md](06-snapshots.md) - Managing snapshots
