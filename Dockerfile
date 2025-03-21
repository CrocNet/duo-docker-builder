# Use an Ubuntu base image
FROM ubuntu:22.04 AS build 

ARG BOARD=default
ENV BOARD=${BOARD}

ENV DEBIAN_FRONTEND=non-interactive

RUN apt-get update \
    && apt-get install -y git ca-certificates joe --no-install-recommends

# Required for duo-buildroot-sdk
RUN apt install -y pkg-config build-essential ninja-build automake autoconf libtool wget curl \
                git gcc libssl-dev bc slib squashfs-tools android-sdk-libsparse-utils jq python3-distutils \
                scons parallel tree python3-dev python3-pip device-tree-compiler ssh cpio fakeroot libncurses5 \
                flex bison libncurses5-dev genext2fs rsync unzip dosfstools mtools tcl openssh-client cmake expect python-is-python3 xxd 


RUN pip install jinja2

RUN update-ca-certificates

WORKDIR /
RUN git clone https://github.com/milkv-duo/duo-buildroot-sdk-v2.git --depth=1 duo-buildroot-sdk
WORKDIR duo-buildroot-sdk
RUN git clone https://github.com/milkv-duo/host-tools.git --depth=1

RUN apt-get clean

CMD bash build.sh lunch

# ------------------------------------------------------------------------------

FROM build AS duo-ubuntu

ARG DISTRO=noble
ENV DISTRO=${DISTRO}

ARG DISTRO_URL=http://ports.ubuntu.com/ubuntu-ports
ENV DISTRO_URL=${DISTRO_URL}

ENV DISTRO_FS=/duo-buildroot-sdk/distro-fs

# Required for ubuntu build
RUN apt install -y debootstrap qemu qemu-user-static binfmt-support dpkg-cross --no-install-recommends

WORKDIR /duo-buildroot-sdk


#Fix SD build.
RUN sed -i 's/\${OUTPUT_DIR}\/\${MILKV_BOARD/\${OUTPUT_DIR}\/\${MV_BOARD/g' build.sh

# Modify build.sh to insert our post build scripts.
RUN sed -i 's/^milkv_build$/milkv_build\nif [ -f post-build.sh ]; then source post-build.sh; fi/' build.sh

#Modify Makefile so that CONFIG_BUILDROOT_FS is not set when packaging sd card and $DISTRO is set
RUN sed -i '/^sd_image:/a \	$(eval CONFIG_BUILDROOT_FS := $(shell [ -n "$$DISTRO" ] && echo "n"))' build/Makefile

#Modify SD card gen to recognise Distro.
RUN sed -i '/^genimage/i if [ -n "$DISTRO" ]; then rm -f ${OUTPUT_DIR}/fs; ln -s ${OUTPUT_DIR}/rootfs ${OUTPUT_DIR}/fs; fi' device/gen_burn_image_sd.sh


RUN mkdir -p /duo-buildroot-sdk/install

COPY ubuntu/post-build.sh .
COPY ubuntu/bootstrap.sh .
COPY device/ device/

CMD bash build.sh lunch

# ------------------------------------------------------------------------------

FROM duo-ubuntu AS duo-ubuntu-arm64

RUN apt install -y gcc-aarch64-linux-gnu gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu 

WORKDIR /duo-buildroot-sdk

ENV ARCH=arm64
ENV QEMU="qemu-aarch64-static"


# generate minimal bootstrap rootfs
RUN update-binfmts --enable
RUN debootstrap --exclude vim --arch=$ARCH --foreign $DISTRO $DISTRO_FS $DISTRO_URL
RUN cp -rf /usr/bin/$QEMU $DISTRO_FS/usr/bin/
RUN cp bootstrap.sh $DISTRO_FS/.

COPY device/*arm* device/
RUN rm -rf device/*risc*

CMD bash build.sh lunch
# ------------------------------------------------------------------------------

FROM duo-ubuntu AS duo-ubuntu-riscv64

ENV ARCH=riscv64
ENV QEMU="qemu-riscv64-static"


RUN apt install -y gcc-riscv64-linux-gnu g++-riscv64-linux-gnu binutils-riscv64-linux-gnu 

WORKDIR /duo-buildroot-sdk

# generate minimal bootstrap rootfs
RUN update-binfmts --enable
RUN debootstrap --exclude vim --arch=$ARCH --foreign $DISTRO $DISTRO_FS $DISTRO_URL
RUN cp -rf /usr/bin/$QEMU $DISTRO_FS/usr/bin/
RUN cp bootstrap.sh $DISTRO_FS/.

COPY device/*risc* device/
RUN rm -rf device/*arm*

CMD bash build.sh lunch