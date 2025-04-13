#!/bin/bash

#Executed by Buildroot, during build process

set -x
set -e

ROOTFS="${BR_DIR}/output/${BR_BOARD}/target"


# enable root login through ssh
sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" ${ROOTFS}/etc/ssh/sshd_config

# Run  proot (chroot-lite)
#proot -S "${ROOTFS}" -q ${QEMU} <bash command>

