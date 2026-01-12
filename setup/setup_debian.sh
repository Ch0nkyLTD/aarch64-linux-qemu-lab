#!/bin/bash

# ==============================================================================
# AArch64 Debian RootFS Builder
# ==============================================================================
# Creates a full Debian 12 (Bookworm) rootfs for ARM64 with development tools.
#
# Architecture (Layered Images):
#   Layer 1: debian-rootfs-base.img (raw)   - Base Debian OS from debootstrap
#   Layer 2: debian-rootfs.qcow2            - Golden image with config + modules
#   Layer 3: debian-runtime.qcow2           - Disposable runtime (via reset)
#
# Usage: sudo ./setup/setup_debian.sh
# ==============================================================================

set -e

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(dirname "$SCRIPT_DIR")"

IMAGE_BASE_NAME="$LAB_ROOT/debian-rootfs-base.img"
IMAGE_NAME="$LAB_ROOT/debian-rootfs.qcow2"
IMAGE_SIZE="4096"  # 4GB for room for dev tools
MOUNT_DIR="$LAB_ROOT/mnt_rootfs"
DEBIAN_RELEASE="bookworm"
KERNEL_SRC="$LAB_ROOT/linux-6.6"

# Packages to install in the rootfs
PACKAGES_BASE="systemd systemd-sysv udev kmod"
PACKAGES_NET="ifupdown iproute2 iputils-ping net-tools openssh-server curl wget"
PACKAGES_DEV="build-essential gcc g++ make gdb strace "
PACKAGES_EDIT="vim nano less"
PACKAGES_UTIL="procps htop tree file man-db bash-completion"
PACKAGES_DEBUG="linux-perf crash"

ALL_PACKAGES="$PACKAGES_BASE $PACKAGES_NET $PACKAGES_DEV $PACKAGES_EDIT $PACKAGES_UTIL"

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root."
    echo "Usage: sudo $0"
    exit 1
fi

# --- Cleanup Trap ---
cleanup() {
    echo ">>> Cleaning up..."

    # Unmount bind mounts first
    for mount in sys proc dev; do
        if mountpoint -q "$MOUNT_DIR/$mount" 2>/dev/null; then
            umount "$MOUNT_DIR/$mount" 2>/dev/null || true
        fi
    done

    # Unmount main directory
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        umount "$MOUNT_DIR" 2>/dev/null || true
    fi

    # Disconnect NBD
    if [ -e /dev/nbd0 ] && lsblk /dev/nbd0 &>/dev/null; then
        qemu-nbd --disconnect /dev/nbd0 2>/dev/null || true
    fi

    # Remove mount dir
    if [ -d "$MOUNT_DIR" ]; then
        rmdir "$MOUNT_DIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# --- Install Build Dependencies ---
echo ">>> Step 1: Installing host dependencies..."
apt-get update -qq
apt-get install -y debootstrap qemu-user-static binfmt-support qemu-utils

# ==============================================================================
# PHASE 1: The Base Image (Raw)
# ==============================================================================
if [ -f "$IMAGE_BASE_NAME" ]; then
    echo ">>> Base image '$IMAGE_BASE_NAME' found. Skipping debootstrap."
else
    echo ">>> Base image not found. Building from scratch (this takes ~10 minutes)..."

    # Create Raw Image
    echo ">>> Creating ${IMAGE_SIZE}MB raw image..."
    dd if=/dev/zero of="$IMAGE_BASE_NAME" bs=1M count="$IMAGE_SIZE" status=progress
    mkfs.ext4 -F "$IMAGE_BASE_NAME"

    # Mount Raw Image
    mkdir -p "$MOUNT_DIR"
    mount -o loop "$IMAGE_BASE_NAME" "$MOUNT_DIR"

    # Debootstrap Stage 1 (download packages)
    echo ">>> Running debootstrap Stage 1..."
    debootstrap --arch=arm64 --foreign "$DEBIAN_RELEASE" "$MOUNT_DIR" http://deb.debian.org/debian/

    # Copy QEMU static binary for Stage 2
    cp /usr/bin/qemu-aarch64-static "$MOUNT_DIR/usr/bin/"

    # Debootstrap Stage 2 (configure packages)
    echo ">>> Running debootstrap Stage 2..."
    chroot "$MOUNT_DIR" /debootstrap/debootstrap --second-stage

    # Setup apt sources
    cat <<EOF > "$MOUNT_DIR/etc/apt/sources.list"
deb http://deb.debian.org/debian $DEBIAN_RELEASE main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $DEBIAN_RELEASE-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $DEBIAN_RELEASE-security main contrib non-free non-free-firmware
EOF

    # Mount virtual filesystems for package installation
    mount --bind /dev "$MOUNT_DIR/dev"
    mount --bind /proc "$MOUNT_DIR/proc"
    mount --bind /sys "$MOUNT_DIR/sys"

    # Install packages
    echo ">>> Installing development packages..."
    chroot "$MOUNT_DIR" apt-get update
    chroot "$MOUNT_DIR" apt-get install -y --no-install-recommends $ALL_PACKAGES

    # Clean up apt cache
    chroot "$MOUNT_DIR" apt-get clean
    chroot "$MOUNT_DIR" rm -rf /var/lib/apt/lists/*

    # Unmount virtual filesystems
    umount "$MOUNT_DIR/sys"
    umount "$MOUNT_DIR/proc"
    umount "$MOUNT_DIR/dev"

    # Unmount base image
    umount "$MOUNT_DIR"
    echo ">>> Base image build complete."
fi

# ==============================================================================
# PHASE 2: The Overlay Image (QCOW2)
# ==============================================================================
echo ">>> Step 2: Creating QCOW2 overlay..."

if [ -f "$IMAGE_NAME" ]; then
    echo "    Removing old overlay..."
    rm "$IMAGE_NAME"
fi

# Create QCOW2 backed by raw base
qemu-img create -f qcow2 -F raw -b "$(basename "$IMAGE_BASE_NAME")" "$IMAGE_NAME"

# ==============================================================================
# PHASE 3: Configure the Overlay
# ==============================================================================
echo ">>> Step 3: Mounting overlay for configuration..."

# Load NBD module
modprobe nbd max_part=8

# Connect QCOW2 to NBD
qemu-nbd --connect=/dev/nbd0 "$IMAGE_NAME"
sleep 1

# Mount
mkdir -p "$MOUNT_DIR"
mount /dev/nbd0 "$MOUNT_DIR"

echo ">>> Step 4: Configuring system..."

# --- Hostname ---
echo "aarch64-lab" > "$MOUNT_DIR/etc/hostname"
cat <<EOF > "$MOUNT_DIR/etc/hosts"
127.0.0.1   localhost
127.0.1.1   aarch64-lab

::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# --- Network Configuration ---
cat <<EOF > "$MOUNT_DIR/etc/network/interfaces"
auto lo
iface lo inet loopback

auto enp0s1
iface enp0s1 inet dhcp
EOF

# --- Root Password (root:root) ---
echo "root:root" | chroot "$MOUNT_DIR" chpasswd

# --- Enable Serial Console ---
chroot "$MOUNT_DIR" systemctl enable serial-getty@ttyAMA0.service 2>/dev/null || true

# --- SSH Configuration ---
# Allow root login and password auth for lab environment
if [ -f "$MOUNT_DIR/etc/ssh/sshd_config" ]; then
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' "$MOUNT_DIR/etc/ssh/sshd_config"
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' "$MOUNT_DIR/etc/ssh/sshd_config"
    chroot "$MOUNT_DIR" systemctl enable ssh 2>/dev/null || true
fi

# --- Fstab ---
cat <<EOF > "$MOUNT_DIR/etc/fstab"
/dev/vda    /       ext4    defaults,noatime    0 1
# Shared folder (mount manually or add to fstab after boot)
# hostshare  /mnt    9p      trans=virtio,version=9p2000.L,nofail 0 0
EOF

# --- Create mount point for shared folder ---
mkdir -p "$MOUNT_DIR/mnt"

# --- Convenience script to mount shared folder ---
cat <<'EOF' > "$MOUNT_DIR/usr/local/bin/mount-shared"
#!/bin/bash
if ! mountpoint -q /mnt; then
    mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt && \
    echo "Shared folder mounted at /mnt"
else
    echo "Shared folder already mounted at /mnt"
fi
EOF
chmod +x "$MOUNT_DIR/usr/local/bin/mount-shared"

# --- Welcome message ---
cat <<'EOF' > "$MOUNT_DIR/etc/motd"
================================================================================
  AArch64 Kernel Development Lab - Debian 12 (Bookworm)
================================================================================

  Credentials:    root / root
  Shared folder:  run 'mount-shared' to mount host's ./shared at /mnt
  SSH access:     ssh -p 10022 root@localhost (from host)

  Installed tools: gcc, gdb, strace, ltrace, vim, nano, htop

================================================================================
EOF

# --- Shell configuration ---
cat <<'EOF' >> "$MOUNT_DIR/root/.bashrc"
# Lab aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Mount shared folder alias
alias mnt='mount-shared'

# Prompt with hostname
PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF

# ==============================================================================
# PHASE 4: Install Kernel Modules
# ==============================================================================
echo ">>> Step 5: Installing kernel modules..."

if [ -d "$KERNEL_SRC" ]; then
    echo "    Found kernel source at $KERNEL_SRC"

    # Check if modules were built
    if [ -f "$KERNEL_SRC/modules.order" ]; then
        make -C "$KERNEL_SRC" \
            ARCH=arm64 \
            CROSS_COMPILE=aarch64-linux-gnu- \
            INSTALL_MOD_PATH="$MOUNT_DIR" \
            modules_install
        echo "    Kernel modules installed."
    else
        echo "    WARNING: Kernel modules not built yet. Run 'make modules' in kernel source."
    fi
else
    echo "    WARNING: Kernel source not found at $KERNEL_SRC"
    echo "    Run setup/setup_kernel.sh first to build the kernel."
fi

# ==============================================================================
# Done
# ==============================================================================
echo ""
echo "=============================================================================="
echo "  SUCCESS: Debian rootfs created!"
echo "=============================================================================="
echo ""
echo "  Base image:    $IMAGE_BASE_NAME"
echo "  Golden image:  $IMAGE_NAME"
echo ""
echo "  Next steps:"
echo "    1. Run 'make run' to start the VM"
echo "    2. Run 'make shared' to start with shared folder"
echo "    3. Run 'make debug' to start with GDB debugging"
echo ""
echo "=============================================================================="

# Trap handles cleanup
