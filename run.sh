#!/bin/bash

#Defaults
DISTRO_HOSTNAME=milkvduo-ubuntu
ROOTPW=milkv


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



# Check if any arguments
for arg in "$@"; do
    if [ "$arg" = "bash" ]; then
        BASHARG="bash"
    fi
    
    if [ "$arg" = "debug" ]; then
        PBDEBUG=true
    fi

done

DOBUILD="true"

function start() {

  if [ "$DOBUILD" = "true" ]; then
     docker build . -t duosdk-${ARCH} --network=host --no-cache --target duo-ubuntu-${ARCH}
  fi   

  mkdir -p images

  docker run --rm -it --net=host --privileged \
                    -v ./images:/duo-buildroot-sdk/out \
                    -e DISTRO_HOSTNAME="${DISTRO_HOSTNAME}" -e ROOTPW="${ROOTPW}" \
                    -e PBDEBUG="${PBDEBUG}" \
                     duosdk-${ARCH} $BASHARG $CHOICE

}

check_docker_image() {
    local image_name="duosdk-${ARCH}"
    local creation_date=""
    local image_info=""

    # Check if the image exists locally
    if docker images --format '{{.Repository}}' | grep -q "^${image_name}$"; then
        # Get the creation date in YYYY-MM-DD HH:MM:SS format
        creation_date=$(docker inspect --format '{{.Created}}' "${image_name}" | 
                       cut -d'T' -f1)
        image_info="${image_name} ${creation_date}"
        
        # Present menu using whiptail
        choice=$(whiptail --title "Docker Image Selection" \
                 --menu "Choose an option" 15 60 2 \
                 "1" "Use existing SDK: ${image_info}" \
                 "2" "Rebuild" \
                 3>&1 1>&2 2>&3)

	[ "$choice" = "1" ] && DOBUILD="false"
    fi
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
    fi
fi

[ -z "$ARCH" ] && exit 0


if [ -n "$BASHARG" ]; then
    start
    exit 0
fi


check_docker_image


# Get list of directories in /dev
DIRS=($(ls -d device/*$ARCH*/ 2>/dev/null | xargs -n 1 basename))

# Create menu options array for whiptail
MENU_OPTIONS=()
for dir in "${DIRS[@]}"; do
    MENU_OPTIONS+=("$dir" "")
done
# Add Full List option at the end
MENU_OPTIONS+=("Full List" "")

# Display menu using whiptail and capture selection
CHOICE=$(whiptail --title "Device Directory Selection" \
    --menu "Choose device" \
    15 60 6 \
    "${MENU_OPTIONS[@]}" \
    3>&1 1>&2 2>&3)

# Check exit status (0 = OK, 1 = Cancel)
EXIT_STATUS=$?

if [ $EXIT_STATUS -eq 1 ]; then
    # User cancelled, exit script
    exit 0
fi

# Set DEVICE variable based on selection
if [ "$CHOICE" = "Full List" ]; then
    DEVICE=""
else
    DEVICE="$CHOICE"
    BASHARG="./build.sh"
fi


start

