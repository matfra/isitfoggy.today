# isitfoggy.today
## Introduction
This uses your Raspberry Pi and its camera to take a bunch of pictures every minutes
and serves them via a small website.
At the end of the day, it will generate a timelapse in mp4 format. Example:
https://zero.isitfoggy.com


NOTE: This code has been running on a raspberry pi zero for 8 years but unless you are stuck with an old raspberry pi zero, you should checkout https://github.com/matfra/fenetre.cam which is a more modern/extensible python rewrite supporting many image sources.


There are configuration files for 
- nginx
- systemd
- cloudflare DNS/cache
- crontab


## Installation

Here is the list of the required dependencies

To take pictures
- raspistill (should already be installed)
- imagemagick

To generate the timelapse
- ffmpeg
- libomxil-bellagio-bin (for GPU accelerated encoding)

To serve the site:
- nginx

To setup your own DNS entry and SSL cert
- certbot
- curl
- jq
- dnsutils

```bash
sudo apt-get update
sudo apt install -y nginx git ffmpeg libomxil-bellagio-bin imagemagick dnsutils jq curl certbot
```

Create the isitfoggy user and home directories
```bash
sudo useradd -d /opt/isitfoggy -m -G video -s /bin/nologin isitfoggy
sudo chmod -R g+w /opt/isitfoggy
```

Add yourself to the isitfoggy group so you can write stuff in that dir
```bash
sudo usermod -G isitfoggy -a $USER
```
Logout and log in to get the new group ownership
Clone the repo and edit the configuration file
```bash
git clone https://github.com:matfra/isitfoggy.today.git /opt/isitfoggy/isitfoggy.today
cd /opt/isitfoggy/isitfoggy.today
```

Edit the configuration file
```bash
cp conf/isitfoggy.conf.example conf/isitfoggy.conf
vim conf/isitfoggy.conf
```

Run the installer that will create a bunch of symlinks, services and stuff
```
sudo ./install.sh
```

### Getting SSL certificate
```
sudo utils/certbot_init.sh
```

### Cloudflare setup
If you are serving this via your home broadband connection, It's highly recommended that you use a CDN to cache the static content.
Once you bought a domain (via gandi.net or godaddy.com for example) you can use Cloudflare manage it.
Cloudflare provide "protection" for your server but also caching which comes handy for timelapse videos.
Users will send requests to publichostname.yourdomain.com and Cloudflare will send you the requests to privatename.yourdomain.com
After you transfer your domain to Cloudflare, create the first A record for you public and private fqdn (full qualified domain names)
And get an API key (in your profile section). Fill all this information in /etc/isitfoggy.conf and run utils/update_dns.sh

```bash
cd utils/update_dns.sh
```

## CREDITS:
- Thanks to https://github.com/stowball/jQuery-rwdImageMaps for the per month daylight browser
- Thanks to https://github.com/mozilla/mozjpeg for fast and efficient JPEG recompression
- Thanks to http://www.fmwconcepts.com/imagemagick/ssim/index.php for difference detection between 2 pictures

## TO-DO:
### Frontend
- Add a javascript realtime fog/visibility analysis
### Backend
- Package everything into a .deb
- Allow people to write their own camera wrapper
- Implement zone defined whitebalance
### Installation
- Remove/template all the things to prevent any hardocded values specific to my setup
- Add steps to compile the mozjpeg libraries
