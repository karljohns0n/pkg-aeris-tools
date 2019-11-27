#!/bin/bash
#
# Test tar archive integrity 
# Specify the folder or the file path to verify with -p PATH
#
# by Karl Johnson -- karljohnson.it@gmail.com -- kj @ Freenode
#
# Version 1.1
#

while getopts :p: option; do
		case "${option}" in
		p)
				FPATH=${OPTARG}
				;;
		\?)
				echo "Script usage: testarchive.sh -p [path OR file]" >&2
				exit 1
				;;
		:)
			echo "Invalid option: $OPTARG requires an argument" 1>&2
			exit 1
			;;
		esac
done

if [ -z "$FPATH" ]; then
	echo "Script usage: testarchive.sh -p [path OR file]" 1>&2
	exit 1
fi

find "$FPATH" -type f \( -iname \*.tar.gz -o -iname \*.tgz \) |while read FNAME; do
	echo "Testing: $FNAME on $(date +"%Y-%m-%d %H:%M:%S")"
	if tar -tzf "$FNAME" >/dev/null 2>/dev/null; then echo "Result: SUCCESS"; else echo "Result: FAILED"; fi
	echo -e "Done testing: $FNAME on $(date +"%Y-%m-%d %H:%M:%S") \n"
done