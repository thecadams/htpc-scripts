#!/bin/bash
# Usage: mythsearch.sh "progname" "starttime" "endtime"
progname=$1
from=$2
until=$3

# Determine what times to use for a search. Either
# 1. show is on at some point within the calendar entry period:
#	show ends during the calendar entry period
#		(p_end >= start && p_end <= end) ||
#	show starts during the calendar entry period
#		(p_start >= start && p_start <= end) ||
# 2. show is on during the start time of the calendar entry
#	(p_start <= start && p_end >= start) ||
# 3. show is on during the end time of the calendar entry
#	(p_start <= end && p_end >= end)

cols="chanid,UNIX_TIMESTAMP(starttime),starttime,endtime,title,description"
echo "select $cols from program
where title like '%$1%'
and (
	(endtime >= '$from' && endtime <= '$until') ||
	(starttime >= '$from' && starttime <= '$until') ||
	(starttime <= '$from' && endtime >= '$from') ||
	(starttime <= '$until' && endtime >= '$until')
)" | mysql -u mythtv -pcIrUf943 mythconverg\
| grep -v "$cols"\
| sed -e "s/,/\\\\,/g" -e "s/\t/,/g"
