#!/bin/bash

set -e

#source ENV

ROOTFS=${OUTPUT_DIR}/rootfs
mkdir -p $ROOTFS


case "$ARCH" in
    "arm64")
        QEMU="qemu-aarch64-static"
        ;;
    "riscv64")
        QEMU="qemu-riscv64-static"
        ;;
esac


# generate minimal bootstrap rootfs
update-binfmts --enable
debootstrap --exclude vim --arch=$ARCH --foreign $DISTRO $ROOTFS $BASE_URL

cp -rf /usr/bin/$QEMU $ROOTFS/usr/bin/
cp bootstrap.sh $ROOTFS/.


# Fix poor qemu speed https://unix.stackexchange.com/questions/759188/some-binaries-are-extremely-slow-with-qemu-user-static-inside-docker
rm $ROOTFS/proc
mkdir -p $ROOTFS/proc
mount -t proc /proc $ROOTFS/proc

# chroot into the rootfs we just created
echo "==========  CHROOT $ROOTFS =========="
chroot $ROOTFS /bin/bash /bootstrap.sh --second-stage --exclude vim
echo "========== EXIT CHROOT =========="

umount $ROOTFS/proc
rm $ROOTFS/bootstrap.sh


cp ${OUTPUT_DIR}/tmp-rootfs/etc/fstab $ROOTFS/etc/.



