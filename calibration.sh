#!/bin/bash
set -euxo pipefail

source $(dirname $(readlink -f $0))/common.sh

while true; do
	pre_flight_checks
	mkdir -p $PIC_DIR/test
	raspistill -rot 180 -n -a 12 -th none -q 16 -o "$PIC_DIR/test/test.jpg"
done
