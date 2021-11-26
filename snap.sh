#!/bin/bash
set -euo pipefail
DEBUG=0
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && DEBUG=1 && set -x

source $(dirname $(readlink -f $0))/common.sh

function get_light() {
    timeout 60 raspistill $(eval echo ${LIGHT_MEASURE_OPTIONS--ISO 100 -drc off -awb sun -ss 1000 -w 160 -h 90 -o $MEASURE_FILE})
    if [[ $? == 124 ]] ; then
	log ERROR "Timeout using raspistill. rebooting"
	sudo reboot
    fi
light_values=$(convert $MEASURE_FILE -resize 1x1 -set colorspace Gray -separate -average txt: |tail -1 |cut -d "(" -f2 |cut -d ")" -f1)
    log $light_values
    echo $light_values | cut -d ',' -f3
}

function get_snap_interval_from_diff() {
    dssim=$(ssim $1 $2 |cut -d '=' -f3)
    echo $dssim | perl -lne 'print int(212*2.718**(-50*$_))'
} 

function get_shutter_speed() {
# https://docs.google.com/spreadsheets/d/1-merFoSUlKPvFpYkskaAGFvJg0_1BtaKPWaCKVzcVBM/edit?usp=sharing
    light=$1

    [[ $light -gt 64000 ]] && echo "-drc low" && return 0
    [[ $light -ge 30000 ]] && echo $light | perl -lne 'printf "-drc high -ss " ;print int(926008-81406*log($_))' && return 0
    [[ $light -ge 5500 ]] && echo $light | perl -lne 'printf "-drc high -ss " ;print int(5.00*1000000-460383*log($_))' && return 0
    [[ $light -ge 100 ]] && echo $light | perl -lne 'printf "-drc high -ss " ;print int(3.48*1000000*exp(-3.15*0.0001*$_))' && return 0
    echo "-drc off -ss 4000000" && return 0

}

function get_snap_interval() {
    light=$1
    # We want to take more picture during the day than during the night.
    # We want to take even more pictures during sunset and sunrise to make beautiful timelapses.
    [[ $light -lt 12 ]] && echo 70 && return 0  #night
    [[ $light -lt 65000 ]] && echo 1 && return 0  #sunrise/sunset
    echo 45 && return 0 #full day
}

function capture() {
    outfile=$1
    light=$2
    ss_flag=$(get_shutter_speed $2)
    log DEBUG "Flags: $ss_flag, "
    awb_flags=""
    timeout 60 raspistill $(eval echo ${CAPTURE_OPTIONS--sh 100 -ISO 100 $ss_flag $awb_flags -sa 7 -w 1920 -h 1080 -n -a 12 -th none -q 16 -o $outfile})
    if [[ $? == 124 ]] ; then
	log ERROR "Timeout using raspistill. rebooting"
	sudo reboot
    fi
}

function create_thumbnail() {
    djpeg -scale 1/8 $1 |cjpeg > $2
}

#Require mozjpeg cjpeg and jpeg binaries as well as exif
function optimize_pic() {
	#Takes jpg as first arg
	read_exif=$(exif -i $1)
	intermediate_speed=$(echo "$read_exif" |grep 0x829a |cut -d "|" -f2 |cut -d " " -f1 |sed 's/\// /')
	light=$(echo "$read_exif" |grep 0x8824 |cut -d "|" -f2)
	[[ $(echo -n $intermediate_speed | wc -c) == 1 ]] && speed="${intermediate_speed} 1" || speed=$intermediate_speed
	djpeg $1 | cjpeg -q 90 > $TMP_OPTPIC_PATH
	exif -c --ifd=EXIF -i --tag 0x829a --set-value "$speed" $TMP_OPTPIC_PATH >/dev/null
	[[ $? == 0 ]] && mv $TMP_OPTPIC_PATH.modified.jpeg $TMP_OPTPIC_PATH
	exif -c --ifd=EXIF -i --tag=0x8827 --set-value=$light $TMP_OPTPIC_PATH >/dev/null
	[[ $? == 0 ]] && mv $TMP_OPTPIC_PATH.modified.jpeg $1 || exit 1
	rm $TMP_OPTPIC_PATH
}

umask 002
#Initialize variables to a safe value
count=0
snap_interval=5
percent_light=0
pre_flight_checks
while true; do
	begin_time=$(date "+%s")
	# Only do check disk space every 10 pictures
	[[ $((count % 10)) == 0 ]] && make_room_on_disk
	TMP_PIC_PATH="$TMP_DIR/snap.jpg"
	TMP_OPTPIC_PATH="$TMP_DIR/optimized.jpg"
	MEASURE_FILE="$TMP_DIR/measure.jpg"
	LOG_FILE="$LOG_DIR/$(basename $0).log"
	cur_date=$(date +%Y-%m-%d)
	cur_time=$(date +%H%M%S)
	[[ -d $PIC_DIR/$cur_date ]] || mkdir -p $PIC_DIR/$cur_date
	# Let's skip light measure if we are in full daylight and snap interval is short. Usually synonym of nice clouds. Let's break that rule after 60 iteration maximum ( ~ 5 minutes max) just to be sure to catch a light change.
	if [[ $percent_light == 65535 ]] && [[ $snap_interval -lt 10 ]] && [[ ! $((count % 48 )) == 0 ]]; then
		log "Skipping light measure to increase snap frequency)"
	else
		percent_light=$(get_light)
	fi
	capture "$TMP_PIC_PATH" $percent_light
	optimize_pic "$TMP_PIC_PATH"
	new_file_path=$PIC_DIR/$cur_date/$cur_time.jpg
	mv $TMP_PIC_PATH $PIC_DIR/$cur_date/$cur_time.jpg
	ln -sf $new_file_path $PIC_DIR/latest.jpg
	cp $PIC_DIR/latest_th.jpg $PIC_DIR/previous_th.jpg
	create_thumbnail $PIC_DIR/latest.jpg $PIC_DIR/latest_th.jpg
	snap_interval=$(get_snap_interval_from_diff $PIC_DIR/previous_th.jpg $PIC_DIR/latest_th.jpg)
	count=$((count + 1))
	end_time=$(date "+%s")
	log "Loop time was $((end_time - begin_time))s. Sleeping ${snap_interval}s"
	sleep $snap_interval
done
