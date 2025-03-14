#!/bin/bash

docker build . -t duosdk --network=host --target duo-ubuntu

mkdir -p output
docker run --rm -it --net=host --privileged -v ./output:/duo-buildroot-sdk/install duosdk