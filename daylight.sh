#!/bin/bash
set -euo pipefail

function get_last_day() {
	basename $(find $PIC_DIR/ -type d -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" |sort -n |tail -2 |head -1) 
}

function usage() {
	echo "usage: $0 [ -d | --dir directory to look into defaults to yesterday] [ -v | --verbose ] | [ -h | --help ]"
}

# Parameters used to select the zone of the sky to average the color from
crop_zone="320x200+80+150"
gravity="North"
force=0

[[ $# -lt 1 ]] && usage && exit 1

while [[ $# -gt 0 ]]; do
	case $1 in
		-v | --verbose )	set -x
					;;
		-f | --force )		force=1
					;;
		-n | --numdays )	shift
					numdays=$1
					;;
		-y | --year )		shift
					year="$1"
					;;
		-m | --month )		shift
					month=$1
					;;
		--from )		shift
					month_from=$1
					;;
		--to )			shift
					month_to=$1
					;;
		-d | --day )		shift
					day=$1
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
		* )			day=get_last_day
					;;
	esac
	shift
done

# Load the common isitfoggy tooling library
source $(dirname $(readlink -f $0))/common.sh 
pre_flight_checks

function generate_day_band() {
	WORKDIR=$1
	[[ ! -d $WORKDIR ]] && echo "WARN $WORKDIR does not exist: Skipping it" && return 0
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

function generate_lastndayview() {
	DEFAULT_COUNT=365
	requested_day_count="${1:-$DEFAULT_COUNT}"

	days=$(find $PIC_DIR -name daylight.png | sort -n |tail -n $requested_day_count)
	day_count=$(echo "$days"|wc -l)
	[[ ! $day_count == $requested_day_count ]] && echo "There is only data for $day_count days but $requested_day_count were requested" && exit 1 
	# Generate the png	
	file_prefix="daylight_last_${day_count}_days"
	convert +append $(echo $days) $PIC_DIR/$file_prefix.png

	# Generate the html
	HTML_DIR=$(dirname $(readlink -f $0))/html
	HTML_FILE=$TMP_DIR/$file_prefix.html
	echo '<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>isitfoggy daylight browser</title>
    <link rel="stylesheet" href="daylight.css">
  </head>
    <body>
      <div class="top">
        <div class="bands">' >> $HTML_FILE
	echo "<img src=\"photos/$file_prefix.png\" usemap=\"#daylight\" width=\"${day_count}\" height=\"1440\">">> $HTML_FILE
	echo "<map name=\"daylight\">" >> $HTML_FILE
	x=0
	for image_dir in $days ; do
		image_of_the_day="/$(echo $image_dir |cut -d '/' -f5-)"
		dirlink="$(echo $image_of_the_day |cut -d '/' -f1-3)/"
		altname="$(echo $dirlink | cut -d '/' -f3)"
		echo "  <area shape=\"rect\" coords=\"$x,0,$((x+1)),1439\" alt=\"$altname\" href=\"$dirlink\">" >> $HTML_FILE
		x="$((x+1))"
	done
	echo '</map>     
      </div>
      
      <div class="right">
          <div class="timeboxeven">12 AM</div>
          <div class="timeboxodd">1 AM</div>
  <div class="timeboxeven">2 AM</div>
  <div class="timeboxodd">3 AM</div>
  <div class="timeboxeven">4 AM</div>
  <div class="timeboxodd">5 AM</div>
  <div class="timeboxeven">6 AM</div>
  <div class="timeboxodd">7 AM</div>
  <div class="timeboxeven">8 AM</div>
  <div class="timeboxodd">9 AM</div>
  <div class="timeboxeven">10 AM</div>
  <div class="timeboxodd">11 AM</div>
  <div class="timeboxeven">12 PM</div>
  <div class="timeboxodd">1 PM</div>
  <div class="timeboxeven">2 PM</div>
  <div class="timeboxodd">3 PM</div>
  <div class="timeboxeven">4 PM</div>
  <div class="timeboxodd">5 PM</div>
  <div class="timeboxeven">6 PM</div>
  <div class="timeboxodd">7 PM</div>
  <div class="timeboxeven">8 PM</div>
  <div class="timeboxodd">9 PM</div>
  <div class="timeboxeven">10 PM</div>
  <div class="timeboxodd">11 PM</div>
  </div>
  </div>
  <div class="bottom">Months and years here</div>
  <script src="lib/jquery.min.js"></script>
  <script src="lib/jquery.rwdImageMaps.min.js"></script>

    <script>
    $(document).ready(function(e) { $("img[usemap]").rwdImageMaps();});
    </script>
    </body>
</html>' >> $HTML_FILE
	mv $HTML_FILE $HTML_DIR/
		
}

function generate_black_band() {
	# Generates a 1x1440px black PNG at the path provided as argument
	convert -size 1x1440 xc:black "$1"
}
		
function generate_month_band() {
	# args: year-month
	
	#Checks
	DAYLIGHT_DIR="$PIC_DIR/daylight"
	[[ -d $DAYLIGHT_DIR ]] || mkdir $DAYLIGHT_DIR
	empty_day_file="$DAYLIGHT_DIR/black.png"
	[[ -f $empty_day_file ]] || generate_black_band $empty_day_file
	result_file="$DAYLIGHT_DIR/$1.png"
	today=$(date "+%Y-%m-%d")

	filelist=""
	for day in $(seq 1 31) ; do
		#Exclude the days that don't exist and add zeros prefixes if needed
		sanitized_date=$(date -d "${1}-${day}" "+%Y-%m-%d") 2>/dev/null || continue
		[[ $today == $sanitized_date ]] && break
		daylight_filepath="$PIC_DIR/$sanitized_date/daylight.png"
		[[ -f $daylight_filepath ]] || generate_day_band $PIC_DIR/$sanitized_date
		if test -f $daylight_filepath ; then
			filelist=$(echo -n "$filelist $daylight_filepath")
		else
			filelist=$(echo -n "$filelist $empty_day_file")
		fi
	done

	# actually create the png
	convert +append $(echo $filelist) -colors 256 PNG8:$result_file
}	

function generate_year_band() {
	# args: year-month
	
	#Checks
	DAYLIGHT_DIR="$PIC_DIR/daylight"
	[[ -d $DAYLIGHT_DIR ]] || mkdir $DAYLIGHT_DIR
	empty_day_file="$DAYLIGHT_DIR/black.png"
	[[ -f $empty_day_file ]] || generate_black_band $empty_day_file
	result_file="$DAYLIGHT_DIR/$1.png"

	today=$(date "+%Y-%m-%d")
	filelist=""
	for month in $(seq 1 12) ; do
		for day in $(seq 1 31) ; do
			#Exclude the days that don't exist and add zeros prefixes if needed
			sanitized_date=$(date -d "${1}-${month}-${day}" "+%Y-%m-%d" 2>/dev/null) || continue
			[[ $today == $sanitized_date ]] && break
			daylight_filepath="$PIC_DIR/$sanitized_date/daylight.png"
			[[ -f $daylight_filepath ]] || generate_day_band $PIC_DIR/$sanitized_date
			if test -f $daylight_filepath ; then
				filelist=$(echo -n "$filelist $daylight_filepath")
			else
				filelist=$(echo -n "$filelist $empty_day_file")
			fi
		done
		[[ $today == $sanitized_date ]] && break
	done

	# actually create the png
	convert +append $(echo $filelist) PNG8:$result_file
}	

function generate_months_from_to() {
	from_year=$(echo $1 | cut -d '-' -f1)
	to_year=$(echo $2 | cut -d '-' -f1)
	from_month=$(echo $1 | cut -d '-' -f2)
	to_month=$(echo $2 | cut -d '-' -f2)

	month_list=""

	for year in $(seq $from_year $to_year) ; do
		for month in $(seq 1 12) ; do
			[[ $month -lt 10 ]] && month=$(echo "0$month")
			[[ -z $month_list ]] && [[ ! $month == $from_month ]] && continue
			month_list=$(echo -n "$month_list $year-$month")
			[[ "$year-$month" == $2 ]] && break
		done
	done

	echo "INFO Will generate daylight monthly bands for:$month_list"

	for m in $month_list ; do
		echo "INFO Generating month: $m"
		generate_month_band $m
	done
}
#main
set +u
if [[ ! -z $year ]] ; then
	set -u
	generate_year_band $year
	exit 0
fi

if [[ ! -z $month_from ]] && [[ ! -z $month_to ]] ; then
	set -u	
	generate_months_from_to $month_from $month_to
	exit 0
fi

if [[ ! -z $month ]] ; then
	set -u
	generate_month_band $month
	exit 0
fi

if [[ ! -z $numdays ]] ; then
	set -u
	generate_lastndayview $numdays
	exit 0
fi
day=$(get_last_day)
working_dir=$PIC_DIR/$day
if [[ $force == 1 ]] || ! test -f $working_dir/daylight.png ; then
	set -u
	generate_day_band $working_dir
	[[ $? == 0 ]] || exit 1
fi

#default
#set +e
#generate_yearview
