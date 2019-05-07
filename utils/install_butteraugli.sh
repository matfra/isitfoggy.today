#!/bin/bash -x
BUILD_DIR=/usr/src/butteraugli
INSTALL_DIR=/usr/local/bin

sudo apt-get update
sudo apt-get -y install make g++ libjpeg-dev libpng-dev
sudo mkdir -p $BUILD_DIR
sudo git clone https://github.com/google/butteraugli.git $BUILD_DIR
(cd $BUILD_DIR/butteraugli && sudo make)
sudo cp $BUILD_DIR/butteraugli/butteraugli $INSTALL_DIR/
