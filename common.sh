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

# This file descriptor 3 redirects to the stdout of the main process.
# So we can log to the main stdout from inside functions
exec 3>&1
function log() {
	[[ $# -lt 1 ]] && return
	case $1 in
		DEBUG | INFO )			LEVEL=$1
						output_fd=3
						shift
						;;
		WARN | ERROR )			LEVEL=$1
						output_fd=2
						shift
						;;
		* )				LEVEL="INFO"
						output_fd=3
						;;
	esac
	[[ $LEVEL == "DEBUG" ]] && [[ ! ${DEBUG:-0} == 1 ]] && return || true
	printf "%s | %s | %s\n" "$LEVEL" "${FUNCNAME[*]:1}" "$*" >&$output_fd
}

function log_to_file() {
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
    [[ -f $1/timelapse.mp4 ]] || return 2
    for f in $(find $1 -type f -name '*.jpg' |sort -n); do
	counter=$(( $counter + 1 ))
        [[ $(( $counter % $archiving_ratio )) == 0 ]] && continue
        rm -f $f
    done
    touch $1/archived
}

function check_user() {
	if [ "$(whoami)" == "isitfoggy" ] ; then
		return 0
	else
		echo "Please run this as user isitfoggy or permissions on files will be messed up. You can use: sudo -u isitfoggy $0"
		exit 1
	fi
}


function pre_flight_checks() {
	check_user
	check_binaries
	check_config
	source $CONFIG_FILE
	test_dir_write $PIC_DIR
	test_dir_write $TMP_DIR
	test_dir_write $LOG_DIR
   	make_room_on_disk
}

function validate_iso_month() {
	echo "$1" |grep -q -E '^[0-9]{4}\-[0-1][0-9]$'
	return $?
}

function sanitize_iso_date() {
	date -d "$1" "+%Y-%m-%d"
}

function fatal () {
	log ERROR "$@"
	exit 1
}
