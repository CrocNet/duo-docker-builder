#!/bin/bash

export MV_BOARD=milkv-duos-glibc-arm64-emmc
export MV_VENDOR=milkv
export MV_BUILD_ENV=envsetup_milkv.sh
export MV_BOARD_LINK=sg2000_milkv_duos_glibc_arm64_emmc

export DISTRO="noble"
export DISTRO_URL="http://ports.ubuntu.com/ubuntu-ports"
export DISTRO_HOSTNAME=${DISTRO_HOSTNAME:-milkvduo-ubuntu}
export ROOTPW=${ROOTPW:-milkv}

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
KERNEL="$SCRIPT_DIR/kernel.conf"

if [ -f "$KERNEL" ]; then
   cat $KERNEL >> /duo-buildroot-sdk/build/boards/cv181x/$MV_BOARD_LINK/linux/*milkv*_defconfig
   rm $KERNEL
fi
