#!/bin/bash
set -euxo pipefail

CONFIG_FILE=/etc/isitfoggy.conf

function check_config() {
    #TODO
    return 0
}

function is_dir_bigger_than() {
    dir=$1
    limit=$2
    dir_size=$(du -s $dir/ |awk '{print $1}')
    limit=$2
    [[ $dir_size -gt $limit ]] && return 0 || return 1
}

function log() {
    echo "$(date): $1" >> $LOG_FILE
}


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

function purge_oldest_day_in_dir() {
    dir=$1
    dir_to_purge=$(find $dir -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -rn |tail -1)
    echo "Purging directory: $dir_to_purge"
    [[ -z $dir_to_purge ]] || rm -rf $dir_to_purge
}

function capture() {
    outfile=$1
    light=$2
    ss_flag=$(get_shutter_speed $2)
    raspistill $(eval echo ${CAPTURE_OPTIONS--sh 100 -ISO 100 -co 15 $ss_flag -sa 7 -w 1620 -h 1080 -n -a 12 -th none -q 16 -o $outfile})
}

function test_dir_write() {
    if ! touch $1/write_test ; then
        echo "Cannot write in $1. Exiting"
        exit 1
    else
        rm -f $1/write_test
    fi
}

function create_thumbnail() {
    convert -resize 600x400 $1 - > $2
}



while true; do
	check_config
	source $CONFIG_FILE
	test_dir_write $PIC_DIR
	test_dir_write $TMP_DIR
	test_dir_write $LOG_DIR

	TMP_PIC_PATH="$TMP_DIR/snap.jpg"
	MEASURE_FILE="$TMP_DIR/measure.jpg"
	LOG_FILE="$LOG_DIR/$(basename $0).log"
	cur_date=$(date +%Y-%m-%d)
	cur_time=$(date +%H%M%S)
	while is_dir_bigger_than "$PIC_DIR" $PIC_DIR_SIZE ; do
		purge_oldest_day_in_dir "$PIC_DIR"
	done
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
