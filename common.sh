# This file should be sourced by bash

CONFIG_FILE=/etc/isitfoggy.conf

function check_config() {
    #TODO
    return 0
}

function check_binaries() {
	for i in cjpeg djpeg exif convert raspistill ; do
		if ! which $i >/dev/null ; then
			echo "Could not find the binary $i, aborting"
			exit 1
		fi
	done
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


function purge_oldest_day_in_dir() {
    dir=$1
    dir_to_purge=$(find $dir -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -rn |tail -1)
    echo "Purging directory: $dir_to_purge"
    [[ -z $dir_to_purge ]] || rm -rf $dir_to_purge
}

function test_dir_write() {
    test -d $1 || mkdir -p $1 
    if ! touch $1/write_test ; then
        echo "Cannot write in $1. Exiting"
        exit 1
    else
        rm -f $1/write_test
    fi
}

function make_room_on_disk() {
	while is_dir_bigger_than "$PIC_DIR" $PIC_DIR_SIZE ; do
		purge_oldest_day_in_dir "$PIC_DIR"
	done
}

function archive_dir() {
# Takes a directory as a first argument and a int as a second arg. One picture in $2 will be kept.
    counter=0
    [[ -z $2 ]] && archiving_ratio=30 || archiving_ratio=$2 # By default, keep 1 file every 30
    [[ -d $1 ]] || return 1
    [[ -f $1/archived ]] && return 2
    for f in $(find $1 -type f -name '*.jpg' |sort -n); do
	counter=$(( $counter + 1 ))
        [[ $(( $counter % $archiving_ratio )) == 0 ]] && continue
        rm -f $f
    done
    touch $1/archived
}


function pre_flight_checks() {
	check_binaries
	check_config
	source $CONFIG_FILE
	test_dir_write $PIC_DIR
	test_dir_write $TMP_DIR
	test_dir_write $LOG_DIR
    make_room_on_disk
}
