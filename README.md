# isitfoggy.today
## Introduction
This is a simple set of bash scripts and stuff that make a timelapse
using a raspberry pi camera. It takes a picture every 100 seconds
during the day and night and every 10 seconds during sunrise/sunset

At the end of the day, it will generate a timelapse in mp4 format

https://isitfoggy.today


Everything is viewable via a simple html page

Configurations for
- nginx
- systemd
- cloudflare DNS/cache
- crontab


## Installation

Please install the following dependencies:

To take pictures
- python
- ffmpeg (If you want HW accelaration on Raspberry Pi: you can build it via the script provided in utils/)

To serve the site:
- nginx

To setup your own DNS entry and SSL cert
- certbot
- curl
- jq

Create the isitfoggy user and home directories
```bash
sudo useradd -d /opt/isitfoggy -m -G video -s /bin/nologin isitfoggy
sudo chmod -R g+w /opt/isitfoggy
```

Add yourself to the isitfoggy group so you can write stuff in that dir
```bash
sudo usermod -G isitfoggy -a $USER
```

Clone the repo and launch the install script
```bash
git clone git@github.com:matfra/isitfoggy.today.git /opt/isitfoggy
cd /opt/isitfoggy
```

Edit the configuration file
```shell
cp conf/isitfoggy.example conf/isitfoggy.conf
vim conf/isitfoggy.conf
```

Run the installer that will create a bunch of symlinks, services and stuff
```
sudo ./install.sh
```



## TO-DO:
### Frontend
- Add a javascript realtime fog/visibility analysis
### Backend
- Package everything into a .deb
- Create a true shared library
- Allow people to write their own camera wrapper
