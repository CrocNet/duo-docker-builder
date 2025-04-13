#!/bin/bash

#Executed by Buildroot, during build process

set -x
set -e

ROOTFS="${BR_DIR}/output/${BR_BOARD}/target"


# Run  proot (chroot-lite)
#proot -S "${ROOTFS}" -q ${QEMU} <bash command>

