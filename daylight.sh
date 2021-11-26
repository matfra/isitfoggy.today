#!/bin/bash
set -euo pipefail

# Defaults args
crop_zone="320x200+80+150"
gravity="North"

function usage() {
	echo "Usage: $0 [OPTIONS]... REQUIRED_FLAG ARGUMENT
Generate an HTML browser for daily pictures allowing the user to find a single day or hour in years worth of data.

Optional flags:
[ -f | --force ] 	Force overwrite the existing daylight data
[ -w | --html_only ] 	Generate only the HTML of a given month, not the png
[ -v | --verbose ] 	Enable debug output via bash -x option
[ -c | --crop_zone ]	Imagemagick crop zone to get the average color of the sky. Defaults to $crop_zone
[ -g | --gravity ]	Imagemagick side of the picture to run the position the crop zone from. Defaults to $gravity

Required flags:
-h | --help 		This help
-b | --browser_only 	Generate the HTML browser only
-m | --month 		Generate the band for a given month. Example: -m 2020-11
-r | --range		Generate the bands for all the months in the range. Example : -r 2020-01,2021-08
"
}

force=0
browser_only=0
html_only=0

[[ $# -lt 1 ]] && usage && exit 1

while [[ $# -gt 0 ]]; do
	case $1 in
		-v | --verbose )	set -x
					;;
		-f | --force )		force=1
					;;
		-w | --html_only )	html_only=1
					;;
		-b | --browser_only )	browser_only=1
					;;
		-c | --crop )		shift
					crop_zone=$1
					;;
		-g | --gravity )	shift
					gravity=$1
					;;
		-m | --month )		shift
					month=$1
					;;
		-d | --day )		shift
					day=$1
					;;
		-r | --range )		shift
					range=$1
					;;
		-h | --help )           usage
					exit
					;;
		* )			usage
					exit
					;;
	esac
	shift
done

# Load the common isitfoggy tooling library
source $(dirname $(readlink -f $0))/common.sh 
log "INFO Preflight checks"
pre_flight_checks
HTML_DIR=$(dirname $(readlink -f $0))/html


##################
# Helper functions

function validate_iso_month() {
	echo "$1" |grep -q -E '^[0-9]{4}\-[0-1][0-9]$'
	return $?
}

function sanitize_iso_date() {
	date -d "$1" "+%Y-%m-%d"
}

function fatal () {
	$message="FATAL $1"
	exit 1
}

################
# Generate bands

function generate_day_band() {
	# Historical: Takes workdir as an argument, typically $PIC_DIR/1986-09-30
	echo "INFO Generating daylight band for data in directory $1"
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

function generate_black_band() {
	# Generates a 1x1440px black PNG at the path provided as argument
	convert -size 1x1440 xc:black "$1"
}
		
function generate_month_band() {
	# args: year-month
	
	echo "INFO $1 Generating month band"
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
		# If there is no daylight data, try to generate it
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

	for m in $month_list ; do
		[[ $html_only == 1 ]] || generate_month_band $m
		generate_month_html $m
	done
}


########################
# HTML GENERATION PART

function dump_html_header() {
	# Takes title of the page as an argument
	title="$1"
	echo "<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=0.8, user-scalable=no\">
    <title>$title</title>
    <link rel=\"stylesheet\" href=\"daylight.css\">
    <!-- Global site tag (gtag.js) - Google Analytics -->
    <script async src=\"https://www.googletagmanager.com/gtag/js?id=G-TVGKVGZXNQ\"></script>
    <script>
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
    
      gtag('config', 'G-TVGKVGZXNQ');
    </script>
  </head>"
}


function generate_html_browser() {
	#Build the list of all daylight monthly files
	#Stitch them together and slap links on them
	daylight_monthly_bands=$(find $PIC_DIR/daylight -type f -regextype sed -regex ".*/[0-9]\{4\}-[0-9]\{2\}\.png" -exec basename \{\} \;|sort -rn) 
	echo "INFO Generating browser HTML file"
	# Generate the html
	HTML_FILE=$TMP_DIR/daylight2.html
	dump_html_header "Daylight browser: isitfoggy" > $HTML_FILE
	echo '  <body>
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
    </div>' >> $HTML_FILE
	echo '    <div class="bands">' >> $HTML_FILE
	for month_band in $daylight_monthly_bands; do 
		width=$(( 1 * $(identify -format "%w"  $PIC_DIR/daylight/$month_band)))
		month_name=$(echo $month_band | cut -d "." -f1)
		month_pretty_name=$(date -d "$month_name-01" "+%b<br>%Y")
		echo "
        <div class=\"band\" style=\"flex-grow:${width};\">
          <div class=\"band_img_and_link\">
            <a class=\"month_link\" href=\"daylight_$month_name.html\">
              <img class=\"month_band\" width=\"${width}px\" height=\"1440px\" src=\"photos/daylight/$month_band\">
            </a>
          </div>
          <div class=\"month\"><p>$month_pretty_name</p></div>
        </div>" >> $HTML_FILE
	done
	echo '
      </div>
    </body>
</html>' >> $HTML_FILE
	mv $HTML_FILE $HTML_DIR/

	exit 0
}

function generate_month_html () {
	echo "INFO $1 Generating month HTML page"
	month=$1
	width=$(( 1 * $(identify -format "%w"  $PIC_DIR/daylight/$month.png)))
	month_pretty_name=$(date -d "$month-01" "+%b %Y")
	month_band_web_path="daylight/$month.png"
	HTML_FILE="$TMP_DIR/daylight_$month.html"
	dump_html_header "$month browser: isitfoggy" > $HTML_FILE
	echo "  <body>
    <img src=\"photos/$month_band_web_path\" usemap=\"#daylight\" width=\"${width}\" height=\"1440\">
    <map name=\"daylight\">" >> $HTML_FILE
	x=0
	for day in $(seq 1 $width) ; do
		[[ $day -lt 10 ]] && day=$(echo "0$day")
		isodate="$month-$day"
		dirlink="photos/$isodate/"
		echo "      <area shape=\"rect\" coords=\"$x,0,$((x+1)),1439\" alt=\"$isodate\" href=\"$dirlink\">" >> $HTML_FILE
		x="$((x+1))"
	done
	echo '    </map>     
    <script src="lib/jquery.min.js"></script>
    <script src="lib/jquery.rwdImageMaps.min.js"></script>
    <script>$(document).ready(function(e) { $("img[usemap]").rwdImageMaps();});</script>
  </body>
</html>' >> $HTML_FILE
	mv $HTML_FILE $HTML_DIR/
		
}




#######
# main

set +u

if [[ $browser_only == 1 ]] ; then
	generate_html_browser
	exit 0
fi

if [[ ! -z $range ]] ; then
	set -u	
	month_from=$(echo "$range" | cut -d ',' -f1)
	validate_iso_month "$month_from" || fatal "Bad iso month from: $month_from"
	month_to=$(echo "$range" | cut -d ',' -f2)
	validate_iso_month "$month_to" || fatal "Bad iso month to: $month_to"
	generate_months_from_to $month_from $month_to
	generate_html_browser
	exit 0
fi

if [[ ! -z $month ]] ; then
	set -u
	validate_iso_month "$month" || fatal "Bad iso month to: $month"
	[[ $html_only == 1 ]] || generate_month_band $month
	generate_month_html $month
	generate_html_browser
	exit 0
fi

if [[ ! -z $day ]] ; then
	sanitized_day=$(sanitize_iso_date "$day")
	working_dir="$PIC_DIR/$sanitized_day"
	month=$(echo $sanitized_day |cut -d '-' -f1-2)
	if [[ $force == 1 ]] || ! test -f $working_dir/daylight.png ; then
		set -u
		generate_day_band $working_dir
		if [[ $? == 0 ]] ; then
			generate_month_band $month
			generate_month_html $month
			generate_html_browser
		else
			exit 1
		fi
	else
		echo "WARN $working_dir/daylight.png already exists. use -f to overwrite"
	fi
fi
