#!/bin/bash -ex
SRC=/usr/src/mozjpeg
BUILD=/usr/src/mozjpeg-build

apt-get update
apt-get -y install pkg-config autoconf automake libtool
git clone https://github.com/mozilla/mozjpeg.git $SRC
cd $SRC
autoreconf -fiv
cd $BUILD
bash $SRC/configure
make
make install
