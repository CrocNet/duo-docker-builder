#!/bin/bash

set -e

if [ -z "$DISTRO" ]; then
    echo "No DISTRO set - skipping"
    return 0
fi


ROOTFS=${OUTPUT_DIR}/rootfs-ubuntu
mkdir -p $ROOTFS


case "$ARCH" in
    "arm64")
        QEMU="qemu-aarch64-static"
        ;;
    "riscv64")
        QEMU="qemu-riscv64-static"
        ;;
esac


if [ "$PBDEBUG" = true ]; then
    echo "PRE debootstrap first stage Press Enter to continue..."
    read
fi


# generate minimal bootstrap rootfs
update-binfmts --enable
debootstrap --exclude vim --arch=$ARCH --foreign $DISTRO $ROOTFS $BASE_URL

cp -rf /usr/bin/$QEMU $ROOTFS/usr/bin/
cp bootstrap.sh $ROOTFS/.


# Fix poor qemu speed https://unix.stackexchange.com/questions/759188/some-binaries-are-extremely-slow-with-qemu-user-static-inside-docker
rm $ROOTFS/proc
mkdir -p $ROOTFS/proc
mount -t proc /proc $ROOTFS/proc


if [ "$PBDEBUG" = true ]; then
    echo "PRE debootstrap second stage - Press Enter to continue..."
    read
fi


# chroot into the rootfs we just created
echo "==========  CHROOT $ROOTFS =========="
chroot $ROOTFS /bin/bash /bootstrap.sh --second-stage --exclude vim
echo "========== EXIT CHROOT =========="

umount $ROOTFS/proc
rm $ROOTFS/bootstrap.sh

if [ "$PBDEBUG" = true ]; then
    echo "POST-CHROOT - Press Enter to continue..."
    read
fi


#Copy the fstab from the default build
cp ${OUTPUT_DIR}/tmp-rootfs/etc/fstab $ROOTFS/etc/.


mv ${OUTPUT_DIR}/rootfs ${OUTPUT_DIR}/rootfs-busybox
mv $ROOTFS ${OUTPUT_DIR}/rootfs


if [ "$PBDEBUG" = true ]; then
    echo "POST-BUILD DEBUG end - Press Enter to continue..."
    read
fi
