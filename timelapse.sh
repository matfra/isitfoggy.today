#!/bin/bash -ex

source $(dirname $(readlink -f $0))/common.sh
pre_flight_checks

function send_to_ftp() {
    ftp -n $FTP_HOST <<END_SCRIPT
    quote USER $FTP_USER
    quote PASS $FTP_PASS
    bin
    put $yesterday_dir/timelapse.mp4 $FTP_REMOTE_DIR/$yesterday_date.mp4
    quit
END_SCRIPT
}


cur_date=$(date +%Y-%m-%d)
today_dir=$PIC_DIR/$cur_date

if [ -z $1 ] ; then
	yesterday_dir=$(find $PIC_DIR/ -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -2 |head -1)
	yesterday_date=$(basename $yesterday_dir)
else
	yesterday_date="$1"
	yesterday_dir=$PIC_DIR/$yesterday_date
fi

log "Today's dir: $today_dir"
log "Yesterday  : $yesterday_dir"

if [[ "$today_dir" == "$yesterday_dir" ]] ; then
	log ERROR "Not creating a timelapse as $cur_date is not over"
	exit 1
fi

timelapse_output=$yesterday_dir/timelapse.mp4

if [ -f $timelapse_output ] ; then
	if ! [ $(stat -c %s $timelapse_output) == 0 ] ; then
		log ERROR "Not creating a timelapse as $timelapse_output already exists"
		exit 1
	fi
fi
nice -n 10 ffmpeg -y -framerate 30 -pattern_type glob -i "$yesterday_dir/*.jpg" -c:v h264_v4l2m2m -b:v 20M -s 1920x1080 -vf format=yuv420p $timelapse_output
chmod 664 $timelapse_output
ln -sf $timelapse_output $PIC_DIR/latest.mp4


log "Running daylight"

nice -n 10 $(dirname $(readlink -f $0))/daylight.sh -d $yesterday_date
three_days_ago=$(find $PIC_DIR/ -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -4 |head -1)
[ -z $1 ] && archive_dir $three_days_ago 20

[[ -z $FTP_HOST ]] || send_to_ftp
