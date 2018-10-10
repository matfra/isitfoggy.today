#!/bin/bash -ex
FFMPEG_SRC_DIR=/tmp/FFmpeg
BRANCH=master
case $(uname -m) in 
armv6l)
    ARCH=armel
    ;;

armv7l)
    ARCH=armhf
    ;;
*)
    [[ -z $ARCH ]] && echo "Not sure about your CPU architecture.
    Please run again and export the ARCH variable."
    ;;
esac

sudo apt-get update
sudo \
apt-get -y install \
libomxil-bellagio-dev \
git \
autoconf \
automake \
build-essential \
libass-dev \
libfreetype6-dev \
libsdl2-dev \
libtheora-dev \
libtool \
libva-dev \
libvdpau-dev \
libvorbis-dev \
libxcb1-dev \
libxcb-shm0-dev \
libxcb-xfixes0-dev \
pkg-config \
texinfo \
wget \
zlib1g-dev \
libx264-dev

mkdir -p $FFMPEG_SRC_DIR
cd $FFMPEG_SRC_DIR

if ! [[ -d $FFMPEG_SRC_DIR/.git ]] ; then
    git clone https://github.com/FFmpeg/FFmpeg.git --depth=1 --branch $BRANCH --single-branch .
else
    git status
    git fetch origin $BRANCH
    git checkout $BRANCH
    git pull origin HEAD
    make clean
fi

nice 10 ./configure --arch=$ARCH --target-os=linux --enable-gpl --enable-omx --enable-omx-rpi --enable-nonfree --enable-mmal --enable-libaom
nice 10 make -j $(nproc --all)
echo sudo make install 
