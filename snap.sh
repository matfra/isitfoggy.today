#!/bin/bash -x

ONE_DAY_TIMELAPSE_DURATION_SEC=60
TIMELAPSE_FRAMERATE=24
PIC_DIR="/var/photos"
PIC_DIR_SIZE=20000000
TMP_PIC_PATH="/tmp/picture.jpg"
DEFAULT_PERCENT_MATCH=92
LOG_FILE="/tmp/snaplog.txt"

function is_dir_bigger_than() {
	dir=$1
	limit=$2
	dir_size=$(du -s $dir |awk '{print $1}')
	limit=$2
	[[ $dir_size -gt $limit ]] && return 0 || return 1
}

function log() {
    echo "$(date): $1" >> $LOG_FILE
}


function get_light() {
    measure_file="/tmp/measure.jpg"
    raspistill -sh -100 -ISO 100 -drc off -awb sun -ss 100000 -w 160 -h 90 -roi 0.3,0.30,0.5,0.4 -o $measure_file
    percent_light=$(convert $measure_file -resize 1x1 txt: |perl -n -e'/\((\d{1,}),(\d{1,}),(\d{1,})\)$/ && print int(100 * ($3 / 255))')
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

function is_picture_close_enough_to_previous() {
	new_pic=$1
	prev_pic=$(readlink -f $2)
	match_percentage=$3
	sq_match_percentage=$(( $match_percentage * $match_percentage ))

    if [[ ! -f $new_pic ]] ; then
		echo "$new_pic doesn't exist, probably a capture problem, will retry"
		return 1
	fi
	if [[ ! -f $prev_pic ]] ; then
		echo "$prev_pic doesn't exist, validating the new picture"
		return 0
	fi
	new_pic_size=$(ls -s $new_pic |cut -d ' ' -f 1)
	prev_pic_size=$(ls -s $prev_pic |cut -d ' ' -f 1)
	sq_pcent_diff_size=$(( ( 100 * new_pic_size / (prev_pic_size + 1 )) * ( 100 * new_pic_size / (prev_pic_size + 1)) ))
	echo "Old pic: $prev_pic_size"
	echo "New pic: $new_pic_size"
	echo "Match: $sq_pcent_diff_size / 10000. Objective: $sq_match_percentage"
	[[ $sq_pcent_diff_size -gt $sq_match_percentage ]] && echo "The two pictures match" && return 0 || return 1
}

function capture_to_file() {
	FEED_URL="rtsp://192.168.31.132/onvif1"
	outfile=$1
	[[ -f $outfile  ]] && rm $outfile
	/usr/bin/ffmpeg -i $FEED_URL -v 16 -vframes 1 -q:v 4 $outfile
}

function capture() {
    outfile=$1
    light=$2
    tmpfile="/tmp/capture.jpg"
    ss_flag=$(get_shutter_speed $2)
    raspistill -sh 100 -ISO 100 -co 15 $ss_flag -sa 7 -w 1920 -h 1080 -roi 0,0.17,0.80,1 -n -a 12 -th none -q 16 -o $outfile
}

cur_user=$(whoami)
if ! touch $PIC_DIR/write_test ; then
	sudo mkdir -p $PIC_DIR
	sudo chown -R $cur_user $PIC_DIR
fi


while true; do
	cur_date=$(date +%Y-%m-%d)
	cur_time=$(date +%H:%M:%S)
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
