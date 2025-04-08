#!/bin/bash

export MV_BOARD=milkv-duos-glibc-arm64-sd
export MV_VENDOR=milkv
export MV_BUILD_ENV=envsetup_milkv.sh
export MV_BOARD_LINK=sg2000_milkv_duos_glibc_arm64_sd

export DISTRO_HOSTNAME=${DISTRO_HOSTNAME:-milkvduo-ubuntu}
export ROOTPW=${ROOTPW:-milkv}

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
KERNEL="$SCRIPT_DIR/kernel.conf"
FSMAP="$SCRIPT_DIR/genimage.cfg"


if [ -f "$KERNEL" ]; then
   cat $KERNEL >> /duo-buildroot-sdk/build/boards/cv181x/$MV_BOARD_LINK/linux/*milkv*_defconfig
   rm $KERNEL
fi

if [ -f "$FSMAP" ]; then
   cp $FSMAP /duo-buildroot-sdk/device/${MV_BOARD}/.
fi

