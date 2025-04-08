#!/bin/bash

# Check if an argument was provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <image_file>"
    exit 1
fi

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "This script requires whiptail. Please install it first."
    exit 1
fi

# Check if image file exists
IMAGE_FILE="$1"
if [ ! -f "$IMAGE_FILE" ]; then
    echo "Image file '$IMAGE_FILE' not found!"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Temporary directory for mounting
TEMP_DIR=$(mktemp -d)

# Function to clean up mounts
cleanup() {
    # Unmount everything in reverse order
    if mountpoint -q "$TEMP_DIR/dev"; then
        umount "$TEMP_DIR/dev"
    fi
    if mountpoint -q "$TEMP_DIR/proc"; then
        umount "$TEMP_DIR/proc"
    fi
    if mountpoint -q "$TEMP_DIR/sys"; then
        umount "$TEMP_DIR/sys"
    fi
    if mountpoint -q "$TEMP_DIR"; then
        umount "$TEMP_DIR"
    fi
    losetup -d "$LOOP_DEV" 2>/dev/null
    rmdir "$TEMP_DIR"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT INT TERM

# Get partition information using fdisk and convert to GB
PARTITIONS=$(fdisk -l "$IMAGE_FILE" | grep "^$IMAGE_FILE" | awk '
{
    size = $3;  # Size in sectors
    unit = $4;  # Unit (usually "," but we ignore it)
    # Convert sectors to GB (assuming 512-byte sectors)
    size_gb = size * 512 / 1024 / 1024 / 1024;
    part_num = substr($1, length($1), 1);  # Get last digit (partition number)
    printf "Partition %s %.2f\n", part_num, size_gb
}')

# Convert partition info to whiptail menu format
MENU_OPTIONS=()
while read -r line; do
    if [ -n "$line" ]; then
        PART_NUM=$(echo "$line" | awk '{print $2}')
        SIZE=$(echo "$line" | awk '{print $3}')
        MENU_OPTIONS+=("$PART_NUM" "Partition $PART_NUM (${SIZE} Gb)")
    fi
done <<< "$PARTITIONS"

# Check if we found any partitions
if [ ${#MENU_OPTIONS[@]} -eq 0 ]; then
    echo "No partitions found in the image!"
    exit 1
fi

# Get just the filename from the full path
FILENAME=$(basename "$IMAGE_FILE")

# Show menu using whiptail with filename as title
SELECTED_PART=$(whiptail --title "$FILENAME" \
    --menu "" \
    15 60 5 \
    "${MENU_OPTIONS[@]}" \
    3>&1 1>&2 2>&3)

# Check if user cancelled
if [ $? -ne 0 ]; then
    echo "Operation cancelled"
    exit 0
fi

# Set up loop device
LOOP_DEV=$(losetup -fP --show "$IMAGE_FILE")

# Mount the selected partition
mount "${LOOP_DEV}p${SELECTED_PART}" "$TEMP_DIR"

# Set up necessary mounts for chroot
mount --bind /dev "$TEMP_DIR/dev"
mount --bind /proc "$TEMP_DIR/proc"
mount --bind /sys "$TEMP_DIR/sys"

echo "Entering chroot environment. Type 'exit' to leave."
chroot "$TEMP_DIR"

echo "Exited chroot environment. Cleaning up..."
# Cleanup happens automatically via trap