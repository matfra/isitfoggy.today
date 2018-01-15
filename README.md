# isitfoggy.today
## Introduction
This is a simple set of bash scripts and stuff that make a timelapse
using a raspberry pi camera. It takes a picture every 100 seconds
during the day and night and every 10 seconds during sunrise/sunset

At the end of the day, it will generate a timelapse in mp4 format

Everything is viewable via a simple html page

Configurations for
- nginx
- systemd
- cloudflare DNS/cache
- crontab

## TO-DO:
### Frontend
- Add a javascript realtime fog/visibility analysis
### Backend
- Package everything into a .deb
- Create a true shared library
