#!/bin/bash

export MV_BOARD=milkv-duo256m-musl-riscv64-sd
export MV_VENDOR=milkv
export MV_BUILD_ENV=envsetup_milkv.sh
export MV_BOARD_LINK=sg2002_milkv_duo256m_musl_riscv64_sd

export DISTRO="noble"
export DISTRO_URL="http://ports.ubuntu.com/ubuntu-ports"
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
