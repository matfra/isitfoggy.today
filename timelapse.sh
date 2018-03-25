#!/bin/bash -ex
CONFIG_FILE=/etc/isitfoggy.conf
source $CONFIG_FILE

FTP_HOST="192.168.31.1"
FTP_USER="anonymous"
FTP_PASS="blah"
FTP_REMOTE_DIR="USB3/isitfoggy_timelapse"

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
	echo "Not creating a timelapse as $cur_date is not over"
	exit 1
fi

while is_dir_bigger_than "$PIC_DIR" $PIC_DIR_SIZE ; do
	purge_oldest_day_in_dir "$PIC_DIR"
done

for i in $(find $yesterday_dir -type f -name '*.jpg' |sort -n) ; do echo "file '$i'" ; done > $PIC_DIR/timelapse.txt

nice -n 10 /usr/local/bin/ffmpeg -f concat -safe 0 -i $PIC_DIR/timelapse.txt -c:v h264_omx -b:v 8M -vf fps=48 $yesterday_dir/timelapse.mp4 && \
ln -sf $yesterday_dir/timelapse.mp4 $PIC_DIR/latest.mp4

[[ -z $FTP_HOST ]] || send_to_ftp

echo "Timelapse complete. Waiting 100 seconds before preloading it into cloudflare cache"
sleep 100
curl "https://isitfoggy.today/photos/latest.mp4?$(( ( ( $(date +%s) / 3600) -11)/24 ))" -o /dev/null

