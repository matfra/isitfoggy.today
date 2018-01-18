#!/bin/bash
sudo apt-get update
sudo apt-get -y install git autoconf automake build-essential libass-dev libfreetype6-dev \
	  libsdl2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev libxcb-shm0-dev \
	    libxcb-xfixes0-dev pkg-config texinfo wget zlib1g-dev libx264-dev

[[ -d FFmpeg ]] || git clone https://github.com/FFmpeg/FFmpeg.git
cd FFmpeg
git pull origin master
make clean
sudo ./configure --arch=armel --target-os=linux --enable-gpl --enable-omx --enable-omx-rpi --enable-nonfree --enable-mmal 
make
