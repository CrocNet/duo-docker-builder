#!/bin/bash

#Executed by Buildroot, during build process

set -x
set -e

ROOTFS="${BR_DIR}/output/${BR_BOARD}/target"


# enable ssh root login
sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" ${ROOTFS}/etc/ssh/sshd_config

#Set default root shell to BASH
sed -i '/^root:/ s|/bin/sh$|/bin/bash|' $1/etc/passwd

# Run  proot (chroot-lite)
#proot -S "${ROOTFS}" -q ${QEMU} <bash command>

