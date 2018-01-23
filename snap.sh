#!/bin/bash -x
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
    raspistill -sh -100 -ISO 100 -drc off -awb sun -ss 100000 -w 160 -h 90 -roi 0.3,0.30,0.5,0.4 -o $MEASURE_FILE
    percent_light=$(convert $MEASURE_FILE -resize 1x1 txt: |perl -n -e'/\((\d{1,}),(\d{1,}),(\d{1,})\)$/ && print int(100 * ($3 / 255))')
    log "percent_blue_light: $percent_light"
    echo $percent_light
}

function get_shutter_speed() {
    percent_light=$1
    [[ $percent_light -gt 86 ]] && return 0
    python -c "print('-ss %d'%int(3000000*2.71828**(-${percent_light}/18.518)))"
}

function get_snap_interval() {
    percent_light=$1
    [[ $percent_light -lt 86 ]] && [[ $percent_light -gt 5 ]] && echo 10 && return 0
    echo 100 && return 0
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
    raspistill ${CAPTURE_OPTIONS--sh 100 -ISO 100 -co 15 $ss_flag -sa 7 -w 1920 -h 1080 -roi 0,0.17,0.80,1 -n -a 12 -th none -q 16 -o $outfile}
}

function test_dir_write() {
    if ! touch $1/write_test ; then
        echo "Cannot write in $1. Exiting"
        exit 1
    fi
}

check_config
source $CONFIG_FILE
test_dir_write $PIC_DIR
test_dir_write $TMP_DIR
test_dir_write $LOG_DIR

TMP_PIC_PATH="$TMP_DIR/snap.jpg"
MEASURE_FILE="$TMP_DIR/measure.jpg"
LOG_FILE="$LOG_DIR/$(basename $0).log"

while true; do
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
	echo "Sleeping"
	sleep $snap_interval
done
