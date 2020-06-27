#!/bin/bash -ex

source $(dirname $(readlink -f $0))/common.sh
pre_flight_checks
LOG_FILE="$LOG_DIR/$(basename $0).log"

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
yesterday_dir=$(find $PIC_DIR/ -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -2 |head -1)
yesterday_date=$(basename $yesterday_dir)

echo "Today's dir: $today_dir"
echo "Yesterday  : $yesterday_dir"

if [[ "$today_dir" == "$yesterday_dir" ]] ; then
	log "Not creating a timelapse as $cur_date is not over"
	exit 1
fi

timelapse_output=$yesterday_dir/timelapse.mp4

if [ -f $timelapse_output ] ; then
	log "Not creating a timelapse as $timelapse_output already exists"
else
	nice -n 10 ffmpeg -framerate 30 -pattern_type glob -i "$yesterday_dir/*.jpg" -c:v h264_omx -b:v 20M -s 1920x1080 $timelapse_output
	chmod 664 $timelapse_output
	ln -sf $timelapse_output $PIC_DIR/latest.mp4

fi

echo "Running daylight"
nice -n 10 $(dirname $(readlink -f $0))/daylight.sh -d $yesterday_dir

three_days_ago=$(find $PIC_DIR/ -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -4 |head -1)
archive_dir $three_days_ago 20

[[ -z $FTP_HOST ]] || send_to_ftp
