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
today_dir=$PIC_DIR/$cur_date
yesterday_dir=$(find $PIC_DIR -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -2 |head -1)

echo "Today's dir: $today_dir"
echo "Yesterday  : $yesterday_dir"

if [[ "$today_dir" == "$yesterday_dir" ]] ; then
	echo "Not creating a timelapse as $cur_date is not over"
	exit 1
fi

while is_dir_bigger_than "$PIC_DIR" $PIC_DIR_SIZE ; do
	purge_oldest_day_in_dir "$PIC_DIR"
done

for i in $(find $yesterday_dir -type f -name '*.jpg' |sort -n) ; do echo "file '$i'" ; done > $PIC_DIR/timelapse.txt

nice -n 10 /usr/local/bin/ffmpeg -f concat -safe 0 -i $PIC_DIR/timelapse.txt -c:v h264_omx -b:v 12M -vf fps=24 $yesterday_dir/timelapse.mp4 && \
ln -sf $yesterday_dir/timelapse.mp4 $PIC_DIR/latest.mp4

echo "Timelapse complete. Waiting 10 seconds before preloading it into cloudflare cache"
sleep 10
curl "https://isitfoggy.today/photos/latest.mp4?$(( ( ( $(date +%s) / 3600) -11)/24 ))" -o /dev/null

