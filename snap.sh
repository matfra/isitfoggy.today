#!/bin/bash
set -euxo pipefail

source $(dirname $(readlink -f $0))/common.sh

function get_light() {
    raspistill $(eval echo ${LIGHT_MEASURE_OPTIONS--ISO 100 -drc off -awb sun -ss 1000 -w 160 -h 90 -o $MEASURE_FILE})
    light_values=$(convert $MEASURE_FILE -resize 1x1 txt: |tail -1 |cut -d "(" -f2 |cut -d ")" -f1)
    log $light_values
    echo $light_values |grep -q 65535 && echo 65535 && return 0 
    echo $light_values | cut -d ',' -f3
}

function get_image_diff() {
    diff=$(butteraugli $1 $2 || echo 30.0)
    echo $diff | cut -d '.' -f1
} 

function get_shutter_speed() {
    blue_light=$1
    [[ $blue_light -gt 60000 ]] && echo "-awb auto -ex auto" && return 0
    [[ $blue_light -gt 40000 ]] && echo $blue_light | perl -lne '$a=int(3810000*2.718**(-0.0000834 * $_)) ; print "-ss $a"' && return 0
    echo $blue_light | perl -lne '$a=int(3810000*2.718**(-0.0000834 * $_)) - 45000 ; print "-ss $a"'
}

function get_snap_interval() {
    blue_light=$1
    # We want to take more picture during the day than during the night.
    # We want to take even more pictures during sunset and sunrise to make beautiful timelapses.
    [[ $blue_light -lt 12 ]] && echo 70 && return 0  #night
    [[ $blue_light -lt 65000 ]] && echo 1 && return 0  #sunrise/sunset
    echo 45 && return 0 #full day
}

function capture() {
    outfile=$1
    light=$2
    ss_flag=$(get_shutter_speed $2)
    raspistill $(eval echo ${CAPTURE_OPTIONS--sh 100 -ISO 100 -co 15 $ss_flag -sa 7 -w 1920 -h 1080 -n -a 12 -th none -q 16 -o $outfile})
}

function create_thumbnail() {
    convert -resize 320x180 $1 - > $2
}


while true; do
	pre_flight_checks

	TMP_PIC_PATH="$TMP_DIR/snap.jpg"
	MEASURE_FILE="$TMP_DIR/measure.jpg"
	LOG_FILE="$LOG_DIR/$(basename $0).log"
	cur_date=$(date +%Y-%m-%d)
	cur_time=$(date +%H%M%S)
	mkdir -p $PIC_DIR/$cur_date
	percent_light=$(get_light)
	diff=$(get_image_diff $PIC_DIR/previous_th.jpg $PIC_DIR/latest_th.jpg)
	snap_interval=$(get_snap_interval $percent_light)
	capture "$TMP_PIC_PATH" $percent_light $diff
	new_file_path=$PIC_DIR/$cur_date/$cur_time.jpg
	cp $TMP_PIC_PATH $PIC_DIR/$cur_date/$cur_time.jpg
	ln -sf $new_file_path $PIC_DIR/latest.jpg
	cp $PIC_DIR/latest_th.jpg $PIC_DIR/previous_th.jpg
	create_thumbnail $PIC_DIR/latest.jpg $PIC_DIR/latest_th.jpg
    echo "Sleeping"
	sleep $snap_interval
done
