#!/bin/bash
set -euxo pipefail

source $(dirname)/common.sh

function get_light() {
    raspistill $(eval echo ${LIGHT_MEASURE_OPTIONS-sh -100 -ISO 100 -drc off -awb sun -ss 100000 -w 160 -h 90 -o $MEASURE_FILE})
    percent_light=$(convert $MEASURE_FILE -resize 1x1 txt: |perl -n -e'/\((\d{1,}),(\d{1,}),(\d{1,})\)$/ && print int(100 * ($3 / 255))')
    log "percent_blue_light: $percent_light"
    [[ $percent_light == 0 ]] && echo 99 && return 0
    echo $percent_light
}

function get_shutter_speed() {
    percent_light=$1
    [[ $percent_light -gt 89 ]] && return 0
    [[ $percent_light -gt 54 ]] && echo $percent_light | perl -lne '$a=int(22000+3910000*2.718**(-$_/17.42)) ; print "-ss $a"' && return 0
    echo $percent_light | perl -lne '$a=int(180000+3810000*2.718**(-$_/12.5)) ; print "-ss $a"'
}

function get_snap_interval() {
    percent_light=$1
    # We want to take more picture during the day than during the night.
    # We want to take even more pictures during sunset and sunrise to make beautiful timelapses.
    [[ $percent_light -lt 6 ]] && echo 120 && return 0  #night
    [[ $percent_light -lt 89 ]] && echo 3 && return 0  #sunrise/sunset
    echo 50 && return 0 #full day
}

function capture() {
    outfile=$1
    light=$2
    ss_flag=$(get_shutter_speed $2)
    raspistill $(eval echo ${CAPTURE_OPTIONS--sh 100 -ISO 100 -co 15 $ss_flag -sa 7 -w 1620 -h 1080 -n -a 12 -th none -q 16 -o $outfile})
}

function create_thumbnail() {
    convert -resize 600x400 $1 - > $2
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
	snap_interval=$(get_snap_interval $percent_light)
	capture "$TMP_PIC_PATH" $percent_light
	new_file_path=$PIC_DIR/$cur_date/$cur_time.jpg
	cp $TMP_PIC_PATH $PIC_DIR/$cur_date/$cur_time.jpg
	ln -sf $new_file_path $PIC_DIR/latest.jpg
	create_thumbnail $PIC_DIR/latest.jpg $PIC_DIR/latest_th.jpg
    echo "Sleeping"
	sleep $snap_interval
done
