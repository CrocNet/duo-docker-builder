#!/bin/bash

#Defaults
DISTRO_HOSTNAME=milkvduo-ubuntu
ROOTPW=milkv


# Check if any arguments
for arg in "$@"; do
    if [ "$arg" = "bash" ]; then
        BASHARG="bash"
    fi
    
    if [ "$arg" = "debug" ]; then
        PBDEBUG=true
    fi

done




docker build . -t duosdk --network=host --target duo-ubuntu

mkdir -p images

docker run --rm -it --net=host --privileged \
                    -v ./images:/duo-buildroot-sdk/out \
                    -e DISTRO_HOSTNAME="${DISTRO_HOSTNAME}" -e ROOTPW="${ROOTPW}" \
                    -e PBDEBUG="${PBDEBUG}" \
                     duosdk $BASHARG