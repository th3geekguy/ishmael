#!/bin/bash
if [ $# -eq 0  ]; then
    echo "This script will strip the leading text from a corrupted"
	echo "tar file created by a single node support dump"
    echo "  Usage: clean_sd.sh <filename>"
    echo "  Produces output file named fixed_<filename>"
	exit 0
fi
pos=$(grep -m 1 -a -b --only-matching $'\x1f\x8b' $1 | awk -F: '{print $1}')
if [ -z "$pos" ]; then
    echo "Did not find gz header"
elif [ $pos -eq 0 ]; then
    echo "File is already a tar/gz file"
else
    pos=$(( pos+1 ))
    tail -c +$pos $1 > fixed_$1
fi

