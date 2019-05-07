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
function get_awb_flags() {
    # Takes one jpg picture and one true grey area coordinates in imagemagick crop format
    # http://www.imagemagick.org/Usage/crop/
    # Outputs aws gains flags (blue and red float multipliers in raspistill format)
    # If no area is specified, outputs awb auto
    # https://www.raspberrypi.org/documentation/raspbian/applications/camera.md
    image=$1
    [[ $# -lt 2 ]] && return
    echo "$2" |grep -q -E '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' || return
    area=$2
    rgb=$(convert -crop $area -resize 1x1 $image txt: |tail -1 |cut -d "(" -f3 |cut -d ")" -f1)
    red=$(echo $rgb |cut -d "," -f1)
    green=$(echo $rgb |cut -d "," -f2)
    blue=$(echo $rgb |cut -d "," -f3)
    blue_gain=$(perl -e "print int(1000 * $green/$blue)/1000")
    red_gain=$(perl -e "print int(1000 * $green/$red)/1000")
    echo "-awb off -awbg $blue_gain,$red_gain"
}

function get_snap_interval_from_diff() {
    dssim=$(ssim $1 $2 |cut -d '=' -f3)
    echo $dssim | perl -lne 'print int(212*2.718**(-50*$_))'
} 

function get_shutter_speed() {
    blue_light=$1
    [[ $blue_light -gt 60000 ]] && return
    [[ $blue_light -gt 40000 ]] && echo $blue_light | perl -lne '$a=int(3810000*2.718**(-0.000085 * $_)) ; print "-ss $a"' && return 0
    echo $blue_light | perl -lne '$a=int(3810000*2.718**(-0.000085 * $_)) - 45000 ; print "-ss $a"'
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
    awb_flags=$(get_awb_flags "$outfile" $AWB_REF_GREY_AREA)
    raspistill $(eval echo ${CAPTURE_OPTIONS--sh 100 -ISO 100 -co 15 $ss_flag $awb_flags -sa 7 -w 1920 -h 1080 -n -a 12 -th none -q 16 -o $outfile})
}

function create_thumbnail() {
    convert -resize 320x180 $1 - > $2
}

umask 002
while true; do
	pre_flight_checks

	TMP_PIC_PATH="$TMP_DIR/snap.jpg"
	MEASURE_FILE="$TMP_DIR/measure.jpg"
	LOG_FILE="$LOG_DIR/$(basename $0).log"
	cur_date=$(date +%Y-%m-%d)
	cur_time=$(date +%H%M%S)
	mkdir -p $PIC_DIR/$cur_date
	percent_light=$(get_light)
	capture "$TMP_PIC_PATH" $percent_light
	new_file_path=$PIC_DIR/$cur_date/$cur_time.jpg
	cp $TMP_PIC_PATH $PIC_DIR/$cur_date/$cur_time.jpg
	ln -sf $new_file_path $PIC_DIR/latest.jpg
	cp $PIC_DIR/latest_th.jpg $PIC_DIR/previous_th.jpg
	create_thumbnail $PIC_DIR/latest.jpg $PIC_DIR/latest_th.jpg
	snap_interval=$(get_snap_interval_from_diff $PIC_DIR/previous_th.jpg $PIC_DIR/latest_th.jpg)
    echo "Sleeping"
	sleep $snap_interval
done
