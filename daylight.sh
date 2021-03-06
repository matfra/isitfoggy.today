#!/bin/bash
set -euo pipefail
function get_yesterday_dir() {
	cur_date=$(date +%Y-%m-%d)
	find $PIC_DIR/ -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -2 |head -1
}

function usage() {
	echo "usage: $0 [ -d | --dir directory to look into defaults to yesterday] [ -v | --verbose ] | [ -h | --help ]"
}

crop_zone="320x200+80+150"
gravity="North"
force=0

while [[ $# -gt 0 ]]; do
	case $1 in
		-v | --verbose )	set -x
					;;
		-f | --force )		force=1
					;;
		-d | --dir )		shift
					working_dir=$1
					;;
		-c | --crop )		shift
					crop_zone=$1
					;;
		-g | --gravity )	shift
					gravity=$1
					;;
		-h | --help )           usage
					exit
					;;
		* )			working_dir=get_yesterday_dir
					;;
	esac
	shift
done

source $(dirname $(readlink -f $0))/common.sh 
pre_flight_checks

function generate_daylight() {
	WORKDIR=$1
	tmpfile=$TMP_DIR/tmp_daylight_$$.txt

	echo "# ImageMagick pixel enumeration: 1,1440,65535,srgb" > $tmpfile
	#Initialize the var with an almost black pixel no matter what
	value="(214,282,292)  #010101  srgb(1,1,1)"
	total_minute_count=0 #Used as y coordinate

	for h in $(seq -w 0 23) ; do
		for m in $(seq -w 0 59) ; do
			pic=$(find $WORKDIR -type f -name ${h}${m}*.jpg |head -1)
			# If no pic found, we will just write the previous value
			if [[ ! -z $pic ]]  ; then
				value=$(convert $pic -gravity North -crop $crop_zone -resize 1x1 txt:|grep "0,0:" |cut -d " " -f2-)
			fi
			echo "0,${total_minute_count}: ${value}" >> $tmpfile
			total_minute_count=$((total_minute_count+1))
		done
	done
	convert $tmpfile $WORKDIR/daylight.png
	rm $tmpfile
}
	
function generate_yearview() {
	days=$(find $PIC_DIR -name daylight.png | sort -n)
	# Generate the png	
	convert +append $(echo $days) $PIC_DIR/light.png

	# Generate the html
	HTML_DIR=$(dirname $(readlink -f $0))/html
	HTML_FILE=$HTML_DIR/daylight_browser.html
	number_of_days=$(echo "$days"|wc -l)
	relative_width=$(echo $number_of_days |perl -lne 'print 100/$_')
	echo "<html><head><title>Daylight for the last $number_of_days days</title></head><body style=\"margin: 0px; background: #0e0e0e;\"><div align=\"center\">" > $HTML_FILE
	for image_dir in $days ; do
		image_of_the_day="/$(echo $image_dir |cut -d '/' -f5-)"
		dirlink="$(echo $image_of_the_day |cut -d '/' -f1-3)/"
		echo "<a style=\"margin-right: -4px;\" href=\"$dirlink\"><img src=\"$image_of_the_day\" width=\"${relative_width}%\" height=\"100%\"></a>" >> $HTML_FILE
	done
	echo "</div></body></html>" >> $HTML_FILE
		
}


#main

if [[ $force == 1 ]] || ! test -f $working_dir/daylight.png ; then
	generate_daylight $working_dir
	[[ $? == 0 ]] || exit 1
fi
set +e
generate_yearview
