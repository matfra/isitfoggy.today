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
- imagemagick

To generate the timelapse
- ffmpeg (If you want HW accelaration on Raspberry Pi: you can build it via the script provided in utils/)
- libomxil-bellagio-dev (If using Raspberry Pi acceleration)

To serve the site:
- nginx

To setup your own DNS entry and SSL cert
- certbot
- curl
- jq
- dnsutils

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
cp conf/isitfoggy.conf.example conf/isitfoggy.conf
vim conf/isitfoggy.conf
```

Run the installer that will create a bunch of symlinks, services and stuff
```
sudo ./install.sh
```

### Cloudflare setup
If you are serving this via your home broadband connection, It's highly recommended that you use a CDN to cache the static content.
Once you bought a domain (via gandi.net or godaddy.com for example) you can use Cloudflare manage it.
Cloudflare provide "protection" for your server but also caching. That means videosfor free to protect your server and cache your content.
Users will send requests to publichostname.yourdomain.com and Cloudflare will send you the requests to privatename.yourdomain.com
After you transfer your domain to Cloudflare, create the first A record for you public and private fqdn (full qualified domain names)
And get an API key (in your profile section). Fill all this information in /etc/isitfoggy.conf and run utils/update_dns.sh


## TO-DO:
### Frontend
- Add a javascript realtime fog/visibility analysis
### Backend
- Package everything into a .deb
- Create a true shared library
- Allow people to write their own camera wrapper
