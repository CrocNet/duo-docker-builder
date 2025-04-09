# Use an Ubuntu base image
FROM ubuntu:22.04 AS duosdk

ARG BOARD=default
ENV BOARD=${BOARD}

ENV DEBIAN_FRONTEND=non-interactive

RUN apt-get update \
    && apt-get install -y git ca-certificates joe --no-install-recommends

# Required for duo-buildroot-sdk
RUN apt install -y pkg-config build-essential ninja-build automake autoconf libtool wget curl \
                git gcc libssl-dev bc slib squashfs-tools android-sdk-libsparse-utils jq python3-distutils \
                scons parallel tree python3-dev python3-pip device-tree-compiler ssh cpio fakeroot libncurses5 \
                flex bison libncurses5-dev genext2fs rsync unzip dosfstools mtools tcl openssh-client cmake expect python-is-python3 xxd \
                qemu-user-static proot


RUN pip install jinja2

RUN update-ca-certificates

WORKDIR /
RUN git clone https://github.com/milkv-duo/duo-buildroot-sdk-v2.git --depth=1 duo-buildroot-sdk

WORKDIR duo-buildroot-sdk
RUN git clone https://github.com/milkv-duo/host-tools.git --depth=1

RUN apt-get clean

CMD bash build.sh lunch

# ------------------------------------------------------------------------------

FROM duosdk AS duosdk-distro

ARG CACHE_BUST=unknown
RUN echo "Cache bust value: $CACHE_BUST"

ARG ROOTFS_OVERLAY=/rootfs_overlay
ENV ROOTFS_OVERLAY=${ROOTFS_OVERLAY}

WORKDIR /duo-buildroot-sdk

# Decompress RootFs overlay
ADD rootfs.tar.gz ${ROOTFS_OVERLAY}
RUN rm -rf ${ROOTFS_OVERLAY}/etc/ld.so*

#Append extra kernel modules for distro
RUN find /duo-buildroot-sdk/build/boards/cv181x -type f -name '*milkv*_defconfig' -path '*/cv181x/*duo*/linux/*' -exec sh -c 'cat ${ROOTFS_OVERLAY}/kernel.conf >> {}' \;
RUN rm ${ROOTFS_OVERLAY}/kernel.conf

# Increase base image size to 1G
RUN sed -i '/^image rootfs\.ext4 {/,/^}/ s/^\(\s*size\s*=\s*\)[^ ]\+/\11G/' /duo-buildroot-sdk/device/milkv*/genimage.cfg
RUN sed -i 's/\(BR2_TARGET_ROOTFS_EXT2_SIZE="\)[^"]*/\11G/' /duo-buildroot-sdk/buildroot-2024.02/configs/milk*duo*_defconfig
RUN sed -i '/label="ROOTFS"/ s/size_in_kb="[0-9]*"/size_in_kb="1258291"/' /duo-buildroot-sdk/build/boards/cv181x/*milkv_duos*_emmc/partition/partition_emmc.xml

#Add our distro RootFS as SKELETON & add post build script
RUN find /duo-buildroot-sdk/buildroot-2024.02/configs -type f -name '*_defconfig' -exec sh \
              -c 'echo "BR2_ROOTFS_SKELETON_CUSTOM=y\nBR2_ROOTFS_SKELETON_CUSTOM_PATH=\"${ROOTFS_OVERLAY}\"\nBR2_ROOTFS_POST_BUILD_SCRIPT=\"/post_build.sh\"\nBR2_INIT_BUSYBOX=n\nBR2_PACKAGE_BUSYBOX=n" >> {}' \;

COPY post_build.sh /
RUN chmod +x /post_build.sh

#Remove default packages we dont need.
RUN sed -i '/^BR2_PACKAGE_/ { /_DUO_/ b; /_CVI_/ b; /_GENIMAGE/ b; d; }' /duo-buildroot-sdk/buildroot-2024.02/configs/milk*duo*_defconfig
         
#Debug (more verbose MAKE)
RUN sed -i 's|\${Q}\$(BR_DIR)/utils/brmake -j\${NPROC} -C \$(BR_DIR)|\$(MAKE) -d V=1 -C \$(BR_DIR)|' /duo-buildroot-sdk/build/Makefile

CMD bash build.sh lunch

# ------------------------------------------------------------------------------

FROM duosdk-distro AS duosdk-arm64

ENV ARCH=arm64
ENV QEMU="qemu-aarch64-static"

WORKDIR /duo-buildroot-sdk

#RUN apt install -y gcc-aarch64-linux-gnu gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu

RUN rm -rf device/*risc*

CMD bash build.sh lunch
# ------------------------------------------------------------------------------

FROM duosdk-distro AS duosdk-riscv64

ENV ARCH=riscv64
ENV QEMU="qemu-riscv64-static"

WORKDIR /duo-buildroot-sdk

#RUN apt install -y gcc-riscv64-linux-gnu g++-riscv64-linux-gnu binutils-riscv64-linux-gnu


RUN rm -rf device/*arm*

CMD bash build.sh lunch