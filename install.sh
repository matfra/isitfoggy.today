#!/bin/bash -x
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

useradd -d /opt/isitfoggy -m -G video -s /bin/nologin isitfoggy
DIRLIST="/var/log/isitfoggy /usr/share/isitfoggy /var/lib/isitfoggy /var/tmp/isitfoggy"

for d in $DIRLIST ; do
    echo $d
    mkdir -p $d
    chown -R isitfoggy $d
done

ln -sf $SCRIPTPATH/conf/systemd/isitfoggy.service /lib/systemd/system/isitfoggy.service
ln -sf $SCRIPTPATH/snap.sh /usr/share/isitfoggy/snap.sh
ln -sf $SCRIPTPATH/timelapse.sh /usr/share/isitfoggy/timelapse.sh
ln -sf $SCRIPTPATH/conf/isitfoggy.conf /etc/isitfoggy.conf

#Installing as a service
systemctl daemon-reload
systemctl enable isitfoggy.service
systemctl start isitfoggy.service
systemctl status isitfoggy.service

#Copying nginx configuration
ln -sf $SCRIPTPATH/html /usr/share/isitfoggy/html
ln -sf $SCRIPTPATH/conf/nginx/isitfoggy /etc/nginx/sites-enabled/isitfoggy
systemctl reload nginx.service

#Setting up cron timelapse
cp $SCRIPTPATH/conf/cron/timelapse /etc/cron.d/timelapse
