#!/bin/bash
set -eo pipefail

[[ $1 == "-v" ]] && set -x

set -u

# Run this file in a tab and open isitfoggy.conf in a new tab.
# Point your browser at the calibration.html file and adjust the
# CALIBRATION_CAPTURE_OPTIONS while the picture a constantly being refreshed

systemctl status isitfoggy.service |grep 'active (running)' && echo "Please, stop the picture service first to prevent conflict in camera usage. You can run: sudo systemctl stop isitfoggy.service" && exit 1

source $(dirname $(readlink -f $0))/common.sh
pre_flight_checks
tmp_picture_dir=$TMP_DIR/test
mkdir -p $tmp_picture_dir
tmp_picture_filepath=$tmp_picture_dir/test.jpg
ln -sf $TMP_DIR/test $PIC_DIR/test

while true; do
	# Reload the options
	source $CONFIG_FILE
	raspistill $(eval echo ${CALIBRATION_CAPTURE_OPTIONS} -n -a 12 -th none -q 16 -o "$tmp_picture_filepath")
done
