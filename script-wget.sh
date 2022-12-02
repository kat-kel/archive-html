#!/bin/bash

DATAFILE=$1  # CSV containing columns "url" and "normalized_url_hash"
ARCHIVEDIR=$2  # Directory in which the archive will be created

if [ ! -d $ARCHIVEDIR ]; then
    mkdir -p $ARCHIVEDIR  # Make the directory if it doesn't already exist
fi

while IFS="," read -r url normalized_url_hash  # assign variables "url" and "normalized_url_hash" to columns encountered, in that order
do
  logfile="${normalized_url_hash}_log"  # assign variable for log file
  timestamp=$(date +%F) # assign variable for timestamp

  cd $ARCHIVEDIR  # go into the archive
    # do everything you need to do
    $(wget -E -H -k -K -p ${fakenews_url} -o ${normalized_url_hash}_log)
    pathsfile=$(cat ${normalized_url_hash}_log | grep "Sauvegarde" | head -1 | tr '«' ',' | tr '»' ' ' | cut -d',' -f2)
    echo "url: ${url}" # url of the fake news 
    echo "logfile: ${logfile}" # hash 
    echo "path_html: ${pathsfile}" 
    echo "timestamp:(${timestamp})"  # timestamp of the wget command 
    echo "" 

  cd .. # go back to the top-level, where the script is saved / from where the script is deployed

done < <(xsv select url,normalized_url_hash  $1)  # Feed loop the standard output from 'xsv select' on 2 columns

# INPUT CSV : url,normalized_url_hash
# in the script : url,logfile,pathsfile,timestamp
# OUTPOUT CSV : url,timestamp_minet_fetch,normalised_url_hash,pathsfile,timestamps_wget

# tested and work on the url from de facto !!