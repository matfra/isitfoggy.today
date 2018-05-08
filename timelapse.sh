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
yesterday_dir=$(find $PIC_DIR/ -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -2 |head -1)
yesterday_date=$(basename $yesterday_dir)

echo "Today's dir: $today_dir"
echo "Yesterday  : $yesterday_dir"

if [[ "$today_dir" == "$yesterday_dir" ]] ; then
	log "Not creating a timelapse as $cur_date is not over"
	exit 1
fi


for i in $(find $yesterday_dir -type f -name '*.jpg' |sort -n) ; do echo "file '$i'" ; done > $PIC_DIR/timelapse.txt

nice -n 10 /usr/local/bin/ffmpeg -f concat -safe 0 -i $PIC_DIR/timelapse.txt -c:v h264_omx -b:v 8M -vf fps=24 $yesterday_dir/timelapse.mp4 && \
ln -sf $yesterday_dir/timelapse.mp4 $PIC_DIR/latest.mp4 && \
archive_dir $yesterday_dir 30

[[ -z $FTP_HOST ]] || send_to_ftp

echo "Timelapse complete. Preloading it into cloudflare cache"
sleep 1
curl "https://isitfoggy.today/photos/latest.mp4?$(( ( ( $(date +%s) / 3600) -11)/24 ))" -o /dev/null

