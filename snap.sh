#!/bin/bash

FEED_URL="rtsp://192.168.31.135/onvif1"
ONE_DAY_TIMELAPSE_DURATION_SEC=20
TIMELAPSE_FRAMERATE=24
PIC_DIR="/var/photos"
PIC_DIR_SIZE=20000000
#PIC_DIR_SIZE=100001

function is_dir_bigger_than() {
	dir=$1
	limit=$2
	dir_size=$(du -s $dir |awk '{print $1}')
	limit=$2
	[[ $dir_size -gt $limit ]] && return 0 || return 1
}

function purge_oldest_day_in_dir() {
	dir=$1
	dir_to_purge=$(find $dir -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -rn |tail -1)
	echo "Purging directory: $dir_to_purge"
	[[ -z $dir_to_purge ]] || rm -rf $dir_to_purge
}

cur_user=$(whoami)
if ! touch $PIC_DIR/write_test ; then
	sudo mkdir -p $PIC_DIR
	sudo chown -R $cur_user $PIC_DIR
fi

pics_per_day=$(( $TIMELAPSE_FRAMERATE * $ONE_DAY_TIMELAPSE_DURATION_SEC ))
snap_interval=$(( 24 * 3600 / $pics_per_day ))

while true; do
	cur_date=$(date +%Y-%m-%d)
	cur_time=$(date +%H:%M:%S)
	while is_dir_bigger_than "$PIC_DIR" $PIC_DIR_SIZE ; do
		purge_oldest_day_in_dir "$PIC_DIR"
	done
	mkdir -p $PIC_DIR/$cur_date
	ffmpeg -i $FEED_URL -vframes 1 -q:v 4 $PIC_DIR/$cur_date/$cur_time.jpg
	ln -sf $PIC_DIR/$cur_date/$cur_time.jpg $PIC_DIR/latest.jpg
	sleep $snap_interval
done
