#!/bin/bash

export MV_BOARD=milkv-duo256m-glibc-arm64-sd
export MV_VENDOR=milkv
export MV_BUILD_ENV=envsetup_milkv.sh
export MV_BOARD_LINK=sg2002_milkv_duo256m_glibc_arm64_sd

export DISTRO="noble"
export DISTRO_URL="http://ports.ubuntu.com/ubuntu-ports"
export DISTRO_HOSTNAME=${DISTRO_HOSTNAME:-milkvduo-ubuntu}
export ROOTPW=${ROOTPW:-milkv}

export CONFIG_BUILDROOT_FS=n

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
KERNEL="$SCRIPT_DIR/kernel.conf"

if [ -f "$KERNEL" ]; then
   cat $KERNEL >> /duo-buildroot-sdk/build/boards/cv181x/$MV_BOARD_LINK/linux/*milkv*_defconfig
   rm $KERNEL
fi
