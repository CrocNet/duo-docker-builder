#!/bin/bash


#Defaults
DISTRO_HOSTNAME=milkvduo
ROOTPW=milkv

POSTBUILD="Distro/post_build.sh"

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "whiptail is not installed."

    # Check if apt is available
    if command -v apt &> /dev/null; then
        echo "Attempting to install whiptail using apt..."
        sudo apt update && sudo apt install -y whiptail

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

PBDEBUG=false

# Check if any arguments
for arg in "$@"; do
    if [ "$arg" = "bash" ]; then
        BASHARG="bash"
    fi
    
    if [ "$arg" = "debug" ]; then
        PBDEBUG=true
    fi

done


# Check if docker command exists
if ! command -v docker &> /dev/null; then
    echo "Error: docker command not found." >&2
    exit 1
fi

IMAGE_PREFIX="duosdk"
if docker ps --format '{{.Image}}' | grep -q "^${IMAGE_PREFIX}"; then
    echo "Error: docker image in use." >&2
    exit 1
fi


DOBUILD="true"

function start() {

  set -e

  [ "$DOBUILD" = "true" ] && CACHE="--no-cache"
   

  mkdir -p images
  
  docker build . -t ${IMAGE} --network=host ${CACHE} --build-arg CACHE_BUST=$(date +%s) \
        --build-arg DISTRO_HOSTNAME=${DISTRO_HOSTNAME} \
        --build-arg ROOTPW=${ROOTPW} \
        --build-arg BUSYBOX_CONF=${BUSYBOX_CONF} \
        --build-arg POSTBUILD=${POSTBUILD} \
  	--target ${IMAGE}
  
  docker run --rm -it --net=host --privileged \
             -v ./images:/duo-buildroot-sdk/out \
             -e DISTRO_HOSTNAME="${DISTRO_HOSTNAME}" -e ROOTPW="${ROOTPW}" \
             -e PBDEBUG="${PBDEBUG}" \
             --name "duosdk-builder" \
             ${IMAGE} $BASHARG $DEVCHOICE
                     
}

check_docker_image() {
    local creation_date=""
    local image_info=""

    # Check if the image exists locally
    if docker images --format '{{.Repository}}' | grep -q "^${IMAGE}$"; then
        # Get the creation date in YYYY-MM-DD HH:MM:SS format
        creation_date=$(docker inspect --format '{{.Created}}' "${IMAGE}" | 
                       cut -d'T' -f1)
        image_info="${IMAGE} ${creation_date}"
        
        # Present menu using whiptail
        choice=$(whiptail --title "Docker Image Selection" \
                 --menu "Choose an option" 15 60 2 \
                 "1" "Use existing SDK: ${image_info}" \
                 "2" "Force Rebuild" \
                 3>&1 1>&2 2>&3)

	[ "$choice" = "1" ] && DOBUILD="false"
    fi
}

function select_distro() {
    # Array to store matching files
    declare -a tar_files=()
    declare -a conf_dirs=()
   
    # Search current directory and subdirectories with absolute paths
    while IFS= read -r -d '' file; do
        # Convert to absolute path using realpath
        abs_file=$(realpath "$file")
        tar_files+=("$abs_file")
    done < <(find "$(pwd)" -type f -name "*-$ARCH*-*.tar.gz" -print0)
   
    # Check and search ../CrocNetDistro if it exists
    if [ -d "../CrocNetDistro" ]; then
        while IFS= read -r -d '' file; do
            # Convert to absolute path using realpath
            abs_file=$(realpath "$file")
            tar_files+=("$abs_file")
        done < <(find "../CrocNetDistro" -name "rootfs" -type d -prune -o -type f -name "*-$ARCH*-*.tar.gz" -print0)
    fi
   
    # --- Search for directories containing busybox.conf in current directory ---
    echo "Searching for directories containing busybox.conf in $(pwd)..."
    for dir in */; do
        # Check if it's actually a directory and contains the file
        # Make sure dir doesn't literally match "*/" if no dirs are found
        if [ -d "$dir" ] && [ -f "${dir}busybox.conf" ]; then
            # Store the relative path (e.g., ./mydir/ or mydir/)
            conf_dirs+=("$dir")
        fi
    done
   
    # Prepare menu options (showing only filenames)
   # menu_options=("Busybox BASH" "")
    for file in "${tar_files[@]}"; do
        filename=$(basename "$file")
        menu_options+=("$filename" "")
    done
   
    # Add found configuration directories (showing directory names)
    for dir in "${conf_dirs[@]}"; do
        # Remove trailing slash for cleaner display if present
        dir_name=$(basename "$dir")
        menu_options+=("$dir_name" "")
    done
   
    # Show whiptail menu and get selection
    selected=$(whiptail --title "Select Distribution" --menu "Choose a tar.gz file or default:" 15 60 7 "${menu_options[@]}" 3>&1 1>&2 2>&3)

    # If user cancelled
    if [ $? -ne 0 ]; then
        exit 0
    fi

    # If Default Busybox was selected, return without setting ROOTFS_TAR
    if [[ ! "$selected" = *.gz ]]; then
        POSTBUILD="$selected/post_build.sh"
        BUSYBOX_CONF="$selected/busybox.conf"
        return 0
    fi
   
    # Find the full path of the selected file
    for file in "${tar_files[@]}"; do
        if [ "$(basename "$file")" = "$selected" ]; then
            # Ensure ROOTFS_TAR is an absolute path
            ROOTFS_TAR=$(realpath "$file")
            return 0
        fi
    done
    echo "Failed to find $selected"
    exit 1
}

CHOICE=$(whiptail --title "Architecture Selection" --menu "Choose an architecture:" 15 60 2 \
"1" "ARM64" \
"2" "RISC-V" \
3>&1 1>&2 2>&3)

# Check the exit status of whiptail (0 means OK, 1 means Cancel)
if [ $? -eq 0 ]; then
    # If-else block based on the user's selection
    if [ "$CHOICE" = "1" ]; then
        ARCH="arm64"
    elif [ "$CHOICE" = "2" ]; then
        ARCH="riscv64"
    else
        exit 0
    fi
fi


[ -z "$ARCH" ] && exit 0


[ -z "$ROOTFS_TAR" ] && select_distro

if [ -n "$ROOTFS_TAR" ]; then 
  # Check if ROOTFS_TAR is set and points to an existing file
  if [ ! -e "$ROOTFS_TAR" ]; then
      echo "Error: ROOTFS_TAR is not set or does not exist"
      exit 1
  fi

  rm -f ./rootfs.tar.gz
  cp "$ROOTFS_TAR" ./rootfs.tar.gz
  IMAGE=duosdk-${ARCH}
else
  IMAGE=duosdk-busybox-${ARCH}
fi

check_docker_image

# Prompt the user, pre-filling with the current value
NEW_HOSTNAME=$(whiptail --title "Hostname Setup" \
                   --inputbox "Enter the desired hostname:" 10 60 \
                   "$DISTRO_HOSTNAME" \
                   3>&1 1>&2 2>&3) # Capture stderr to stdout

# Check exit status ($?): 0 means OK, non-zero means Cancel/Esc
exitstatus=$?
if [ $exitstatus = 0 ]; then
    DISTRO_HOSTNAME="$NEW_HOSTNAME" # Update variable only if OK was pressed
    echo "Hostname set to: $DISTRO_HOSTNAME"
else
    exit 1
fi

NEW_ROOTPW=$(whiptail --title "Root Password Setup" \
                 --inputbox "Enter the root password:" 10 60 \
                 "$ROOTPW" \
                 3>&1 1>&2 2>&3) # Capture stderr to stdout

exitstatus=$?
if [ $exitstatus = 0 ]; then
    ROOTPW="$NEW_ROOTPW"
    echo "Root password has been set/updated."
else
    exit 1
fi


start
