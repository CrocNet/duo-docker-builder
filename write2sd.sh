#!/bin/bash
set -e

IMAGE_DIR="images"

# Check if the script is running as root
if [ "$(id -u)" -ne 0 ]; then
    # Not running as root, prompt for root password and rerun the script
    echo "This script needs to run with root privileges."
    sudo "$0" "$@"
    exit $?
fi

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "whiptail is not installed."

    # Check if apt is available
    if command -v apt &> /dev/null; then
        echo "Attempting to install whiptail using apt..."
        apt update && apt install -y whiptail

        # Verify if whiptail installed successfully
        if command -v whiptail &> /dev/null; then
            echo "whiptail installed successfully."
        else
            echo "Failed to install whiptail."
            exit 1
        fi
    else
        echo "apt is not available on this system. Cannot install whiptail automatically."
        exit 1
    fi
fi

# Check if a command-line argument was provided
if [ $# -gt 0 ]; then
    # Check if the argument ends with .img
    if [[ "$1" =~ \.img$ ]]; then
        # Check if $IMAGE_DIR directory exists
        if [ -d "$IMAGE_DIR" ]; then        
            IMAGE_FILE="$1"
            IMAGE_FILE=${IMAGE_FILE#$IMAGE_DIR/}                
            # Check if the file exists in $IMAGE_DIR directory
            if [ -f "$IMAGE_DIR/$IMAGE_FILE" ]; then
                IMAGE_FILE="$IMAGE_DIR/$IMAGE_FILE"
            fi
        else
            echo "Directory '$IMAGE_DIR' does not exist"
        fi
    else
        echo "Argument must be a filename ending in .img"
    fi
else
    # No argument provided, use whiptail menu
    if [ -d "$IMAGE_DIR" ]; then
        # Create array of .img files
        mapfile -t img_array < <(ls $IMAGE_DIR/*.img 2>/dev/null)
        
        # Check if array has any elements
        if [ ${#img_array[@]} -gt 0 ]; then
            # Build whiptail menu options
            MENU_OPTIONS=()
            for i in "${!img_array[@]}"; do
                MENU_OPTIONS+=("$i" "${img_array[$i]}")
            done
            
            # Display menu and store selection
            CHOICE=$(whiptail --title "Select Image File" \
                            --menu "Choose an .img file:" \
                            15 80 6 \
                            "${MENU_OPTIONS[@]}" \
                            3>&1 1>&2 2>&3)
            
            # Check if user made a selection
            if [ $? -eq 0 ]; then
                IMAGE_FILE="${img_array[$CHOICE]}"
                echo "Selected image file: $IMAGE_FILE"
            else
                echo "No file selected"
            fi
        else
            echo "No .img files found in $IMAGE_DIR directory"
        fi
    else
        echo "Directory '$IMAGE_DIR' does not exist"
    fi
fi


# Check if the image file exists
if [ ! -f "$IMAGE_FILE" ]; then
    echo "Image file not found: $IMAGE_FILE"
    echo "write2sd.sh" 
    echo "write2sd.sh [image file]"
    exit 1
fi

# Check if the image file is mounted
if mount | grep -q "$IMAGE_FILE"; then
    echo "The image file is mounted! - Exiting."
    exit 1
fi

while true; do
    # Get the list of removable devices and store it in a variable
    DEVICE_LIST=$(lsblk -d -n -p -o NAME,SIZE,RM | awk '$3=="1"{print $1, "("$2")"}')
    DEVICE_LIST_ARRAY=($DEVICE_LIST "rescan" "(rescan devices)")

    # Use whiptail to show a menu to select the SD card, including a rescan option
    SD_CARD_DEVICE=$(whiptail --title "Select SD Card" --menu "Choose the SD Card to use or Rescan" 20 60 10 "${DEVICE_LIST_ARRAY[@]}" 3>&2 2>&1 1>&3)

    # Check if a device was selected
    if [ -z "$SD_CARD_DEVICE" ]; then
        echo "No device selected."
        exit 1
    elif [ "$SD_CARD_DEVICE" = "rescan" ]; then
        continue # Go back to the start of the loop to rescan
    else
        echo "Selected device: $SD_CARD_DEVICE"
        break # Exit loop if a device other than rescan is selected
    fi
done


# Confirm before proceeding
if ! whiptail --yesno "Are you sure you want to write to $SD_CARD_DEVICE?" 10 60; then
    echo "Operation cancelled."
    exit 1
fi


# Unmount the SD card
echo "Unmounting $SD_CARD_DEVICE..."
sudo umount ${SD_CARD_DEVICE}* 2> /dev/null || true  # Proceed even if unmount fails, but check next
if mount | grep -q "^$SD_CARD_DEVICE"; then
    echo "Error: Failed to unmount $SD_CARD_DEVICE partitions. Please ensure no partitions are in use."
    exit 1
fi


set -e

# Copy the image to the SD card using dd
IMAGE_SIZE=$(stat -c %s "$IMAGE_FILE")
SD_SIZE=$(sudo blockdev --getsize64 "$SD_CARD_DEVICE")
if [ "$IMAGE_SIZE" -gt "$SD_SIZE" ]; then
    echo "Error: SD card ($SD_SIZE bytes) is smaller than image ($IMAGE_SIZE bytes)."
    exit 1
fi
echo "Copying image to $SD_CARD_DEVICE. This may take a while..."
sudo dd if="$IMAGE_FILE" of="$SD_CARD_DEVICE" bs=4M status=progress conv=fdatasync

echo "Syncing..."
sync
echo "Copy complete."

# Inform the OS of partition table changes
sudo partprobe "$SD_CARD_DEVICE"


echo "Expaning rootfs..."

fdisk -l $SD_CARD_DEVICE
# Identify the last partition
# Get the number of the last partition
PART_NUM=$(sudo parted $SD_CARD_DEVICE -ms print | awk -F: 'END{print $1}')

# Determine the correct partition device name
if [[ $SD_CARD_DEVICE == /dev/mmcblk* ]]; then
    PART_DEV="${SD_CARD_DEVICE}p${PART_NUM}"
else
    PART_DEV="${SD_CARD_DEVICE}${PART_NUM}"
fi

# Check if the partition exists
if [ ! -b "$PART_DEV" ]; then
    echo "Error: Partition $PART_DEV does not exist."
    exit 1
fi

FS_TYPE=$(sudo blkid -o value -s TYPE "$PART_DEV")
if [[ "$FS_TYPE" != "ext2" && "$FS_TYPE" != "ext3" && "$FS_TYPE" != "ext4" ]]; then
    echo "Error: Partition $PART_DEV is not an ext2/3/4 filesystem."
    exit 1
fi

# Resize last partition to extend to 100% of the disk
sudo parted $SD_CARD_DEVICE resizepart $PART_NUM 100%

sync

fdisk -l $SD_CARD_DEVICE


sudo e2fsck -f "$PART_DEV"
if [ $? -ge 4 ]; then
    echo "Error: Filesystem check failed with critical errors."
    exit 1
fi

echo "Partition and filesystem resize completed."

echo "Ejecting the SD card..."
eject "$SD_CARD_DEVICE"