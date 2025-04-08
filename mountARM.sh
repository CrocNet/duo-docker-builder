#!/bin/bash

# Check if script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)."
  exit 1
fi

# Check if rootfs path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/aarch64/rootfs"
  exit 1
fi

ROOTFS_PATH="$1"

# Check if the provided path exists and is a directory
if [ ! -d "$ROOTFS_PATH" ]; then
  echo "Error: '$ROOTFS_PATH' is not a valid directory."
  exit 1
fi

# Step 1: Check and install QEMU user mode if needed (Debian/Ubuntu assumed)
echo "Checking for QEMU user mode installation..."
if ! dpkg -l | grep -q "qemu-user" || ! dpkg -l | grep -q "qemu-user-static" || ! dpkg -l | grep -q "binfmt-support"; then
  echo "QEMU user mode tools not fully installed. Installing..."
  apt update
  apt install -y qemu-user qemu-user-static binfmt-support
  if [ $? -ne 0 ]; then
    echo "Error: Failed to install QEMU packages."
    exit 1
  fi
else
  echo "QEMU user mode tools already installed."
fi

# Step 2: Ensure QEMU is registered with binfmt_misc
echo "Registering QEMU with binfmt_misc..."
if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
  update-binfmts --enable qemu-aarch64
  if [ $? -ne 0 ]; then
    echo "Error: Failed to register qemu-aarch64 with binfmt_misc."
    exit 1
  fi
else
  echo "qemu-aarch64 already registered."
fi

# Step 3: Copy QEMU binary into the rootfs
QEMU_BINARY="/usr/bin/qemu-aarch64-static"
if [ ! -f "$QEMU_BINARY" ]; then
  echo "Error: QEMU binary '$QEMU_BINARY' not found."
  exit 1
fi

echo "Copying QEMU binary to rootfs..."
cp "$QEMU_BINARY" "$ROOTFS_PATH/usr/bin/"
if [ $? -ne 0 ]; then
  echo "Error: Failed to copy QEMU binary to '$ROOTFS_PATH/usr/bin/'."
  exit 1
fi

# Step 4: Mount necessary filesystems
echo "Mounting necessary filesystems..."
for mountpoint in dev proc sys dev/pts; do
  if ! mountpoint -q "$ROOTFS_PATH/$mountpoint"; then
    mount --bind "/$mountpoint" "$ROOTFS_PATH/$mountpoint"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to mount '/$mountpoint' to '$ROOTFS_PATH/$mountpoint'."
      exit 1
    fi
  else
    echo "'/$mountpoint' already mounted."
  fi
done

# Optional: Copy resolv.conf for networking
#echo "Copying /etc/resolv.conf for networking..."
#cp /etc/resolv.conf "$ROOTFS_PATH/etc/resolv.conf"
#if [ $? -ne 0 ]; then
#  echo "Warning: Failed to copy resolv.conf. Networking may not work."
#fi

# Step 5: Chroot into the environment
echo "Chrooting into '$ROOTFS_PATH'..."
chroot "$ROOTFS_PATH" /bin/bash

# Note: Script ends here as chroot takes over. Cleanup (unmounting) would need a separate script or manual steps.
echo "Exited chroot. You may need to manually unmount filesystems:"
echo "  umount $ROOTFS_PATH/dev/pts $ROOTFS_PATH/dev $ROOTFS_PATH/proc $ROOTFS_PATH/sys"