## Build Milk-V Duo Ubuntu images ARM64 & RISC-V  
  
  
Requires Docker.  Runs on Ubuntu (should work on all debian based distros)
 
    git clone https://github.com/CrocNet/duo-docker-builder.git  
    cd duo-docker-builder  

  
#### ./run.sh  
  
This builds the image, using duo-buildroot-sdk-v2  

    /run.sh  
    ./run.sh [borad name]  

Your complete image will be in the `images` directory.  
  
#### ./copy2sd.sh  
  
Menu driven copy to your sd card.  

    ./copy.sh  
    ./copy.sh [.img file path]

#### Defaults

Edit run.sh to change the defaults

    DISTRO_HOSTNAME=milkvduo-ubuntu
    ROOTPW=milkv