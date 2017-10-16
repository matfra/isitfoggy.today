#!/bin/bash

TIMELAPSE_FRAMERATE=24
PIC_DIR="/var/photos"
PIC_DIR_SIZE=20000000

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

cur_date=$(date +%Y-%m-%d)
yesterday_dir=$(find $PIC_DIR -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -2 |head -1)

if [[ "$cur_date" == "$yesterday_dir" ]] ; then
	echo "Not creating a timelapse as $cur_date is not over"
	exit 1
fi

while is_dir_bigger_than "$PIC_DIR" $PIC_DIR_SIZE ; do
	purge_oldest_day_in_dir "$PIC_DIR"
done

for i in $(find $PIC_DIR/$yesterday_dir -type f -name '*.jpg' |sort -n) ; do echo "file '$i'" ; done > $PIC_DIR/timelapse.txt

nice -n 10 ffmpeg -f concat -safe 0 -i $PIC_DIR/timelapse.txt -vcodec libx264 -vf format=yuv420p -vf fps=24 -pix_fmt yuv420p $PIC_DIR/$yesterday_dir/timelapse.mp4
ln -sf $PIC_DIR/$yesterday_dir/timelapse.mp4 $PIC_DIR/yesterday_timelapse.mp4
