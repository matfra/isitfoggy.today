#!/bin/bash -x
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
CONFIG_FILE=$SCRIPTPATH/conf/isitfoggy.conf

source $CONFIG_FILE

#useradd -d /opt/isitfoggy -m -G video -s /bin/nologin isitfoggy
DIRLIST="/var/log/isitfoggy /usr/share/isitfoggy /var/lib/isitfoggy /var/tmp/isitfoggy /var/lib/isitfoggy/photos"

for d in $DIRLIST ; do
    echo $d
    mkdir -p $d
    chown -R isitfoggy.isitfoggy $d
done

ln -sf $SCRIPTPATH/conf/systemd/isitfoggy.service /lib/systemd/system/isitfoggy.service
ln -sf $SCRIPTPATH/common.sh /usr/share/isitfoggy/common.sh
ln -sf $SCRIPTPATH/snap.sh /usr/share/isitfoggy/snap.sh
ln -sf $SCRIPTPATH/timelapse.sh /usr/share/isitfoggy/timelapse.sh
ln -sf $SCRIPTPATH/utils/ssim /usr/local/bin/ssim
ln -sf $CONFIG_FILE /etc/isitfoggy.conf

#Installing as a service
systemctl daemon-reload
systemctl enable isitfoggy.service
systemctl start isitfoggy.service
systemctl status isitfoggy.service

#Copying nginx configuration
ln -sf $SCRIPTPATH/html /usr/share/isitfoggy/html
ln -sf $SCRIPTPATH/conf/nginx/isitfoggy /etc/nginx/sites-enabled/isitfoggy
rm /etc/nginx/sites-enabled/default
systemctl reload nginx.service

#Setting up cron timelapse
cp $SCRIPTPATH/conf/cron/timelapse /etc/cron.d/timelapse

#Setup the proper domain name in manifest.json
sed "s/isitfoggy.com/${PUBLIC_FQDN}/" $SCRIPTPATH/html/manifest.json

if [[ ! -z $TURN_OFF_PIZERO_LED ]] ; then
    # Set the Pi Zero ACT LED trigger to 'none'.
    echo none | sudo tee /sys/class/leds/led0/trigger
    
    # Turn off the Pi Zero ACT LED.
    echo 1 | sudo tee /sys/class/leds/led0/brightness

    echo '# Disable the ACT LED on the Pi Zero.
    dtparam=act_led_trigger=none
    dtparam=act_led_activelow=on' >> /boot/config.txt
fi

