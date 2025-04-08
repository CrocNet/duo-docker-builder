## Build Milk-V Duo Ubuntu images ARM64 & RISC-V  
  
  
Requires Docker.  Runs on Ubuntu (should work on all debian based distros)

1. Create a distro

    git clone https://github.com/CrocNet/CrocNetDistro.git
    cd CrocNetDistro
    ./run.sh
    cd ..

2. Instal Docker Builder 

    git clone https://github.com/CrocNet/duo-docker-builder.git  
    cd duo-docker-builder  

  
#### ./run.sh  
  
This builds the image, using duo-buildroot-sdk-v2  

    /run.sh  

Your complete image will be in the `images` directory.  
  
#### ./write2sd.sh  
  
Menu driven sd card writer.  

    ./write2sd.sh
    ./write2sd.sh [.img file path]

#### ./write2emmc.sh
  
Creates an SD card installer with emmc build. 

    ./write2emmc.sh
    ./write2emmc.sh [.img file path]
