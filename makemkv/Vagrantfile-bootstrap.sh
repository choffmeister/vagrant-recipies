#!/usr/bin/env bash

MAKEMKV_VERSION="1.8.4"

## ========================
## Install basics
## ========================

# update packages
aptitude update

# install packages
aptitude install -y vim
aptitude install -y curl
aptitude install -y git
aptitude install -y screen

## ========================
## Install MakeMKV
## ========================

# packages needed to build MakeMKV
aptitude install -y build-essential libc6-dev libssl-dev libexpat1-dev libgl1-mesa-dev libqt4-dev

# download and untar makemkv-bin
wget http://www.makemkv.com/download/makemkv-bin-1.8.4.tar.gz
tar xfz makemkv-bin-1.8.4.tar.gz
cd makemkv-bin-1.8.4

# uncomment the following line to make the installation work without interaction,
# but note, that you have to accept the EULA anyway
#echo -e '#!/bin/bash\nexit 0\n' > src/ask_eula.sh

# build and install
make -f makefile.linux
make -f makefile.linux install
cd ..

# download and untar makemkv-oss
wget http://www.makemkv.com/download/makemkv-oss-1.8.4.tar.gz
tar xfz makemkv-oss-1.8.4.tar.gz
cd makemkv-oss-1.8.4

# build and install
make -f makefile.linux
make -f makefile.linux install
cd ..

## ========================
## Exit
## ========================

exit 0
