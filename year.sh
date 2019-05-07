#!/bin/bash -e
list=$1
tmpfile=$(mktemp)
# Start the very first day with a black pixel
value="(214,282,292)  #010101  srgb(1,1,1)"
# This global variable will be used to keep the previous pixel reference
echo $tmpfile
day_count=0
for dir in $(cat $list) ; do
	total_minute_count=0 #Used as y coordinate
	for h in $(seq -w 0 23) ; do
		for m in $(seq -w 0 59) ; do
			#echo -n "${total_minute_count}: "
			pic=$(find $dir -type f -name ${h}${m}*.jpg |head -1)
			if [[ ! -z $pic ]]  ; then
				value=$(convert $pic -gravity North -crop 320x200+80+150 -resize 1x1 txt:|grep "0,0:" |cut -d " " -f2-)
			fi
			echo "${day_count},${total_minute_count}: ${value}" >> $tmpfile
			total_minute_count=$((total_minute_count+1))
		done
	done
	echo "done day $day"
	day_count=$((day_count+1))
done
magikfile=$(mktemp)
echo "# ImageMagick pixel enumeration: ${day_count},${total_minute_count},65535,srgb" > $magikfile
cat $tmpfile >> $magikfile
convert $magikfile -scale 2560\!x1440 "one_year_per_minute.png"
