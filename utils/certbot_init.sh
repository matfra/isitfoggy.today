#!/bin/bash -x
CONFIG_FILE="/etc/isitfoggy.conf"
source $CONFIG_FILE
systemctl stop nginx
certbot --nginx -d $ORIGIN_FQDN
systemctl start nginx
