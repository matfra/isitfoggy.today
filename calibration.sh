#!/bin/bash
set -euxo pipefail

while true; do
	source $(dirname $(readlink -f $0))/common.sh
	pre_flight_checks
	mkdir -p $PIC_DIR/test
	raspistill $(eval echo ${CALIBRATION_CAPTURE_OPTIONS} -n -a 12 -th none -q 16 -o "$PIC_DIR/test/test.jpg")
done
