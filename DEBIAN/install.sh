#!/bin/bash
sudo useradd -d /opt/isitfoggy -m -G video -s /bin/nologin isitfoggy
DIRLIST=/var/log/isitfoggy /usr/share/isitfoggy /var/lib/isitfoggy

for d in $DIRLIST ; do
    mkdir $d
    chown -R isitfoggy $d
done

#Installing as a service
ln -s /opt/isitfoggy/systemd/isitfoggy.service /lib/systemd/system/isitfoggy.service
systemctl enable isitfoggy
systemctl start isitfoggy

