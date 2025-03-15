#!/bin/bash


DISTRO_HOSTNAME=milkvduo-ubuntu
ROOTPW=milkv


docker build . -t duosdk --network=host --target duo-ubuntu

mkdir -p images
docker run --rm -it --net=host --privileged \
                    -v ./images:/duo-buildroot-sdk/out \
                    -e DISTRO_HOSTNAME="${DISTRO_HOSTNAME}" -e ROOTPW="${ROOTPW}" \
                     duosdk