#!/bin/bash

DATAFILE=$1  # CSV containing columns "url" and "normalized_url_hash"
ARCHIVEDIR=$2  # Directory in which the archive will be created

mkdir -p $ARCHIVEDIR  # Make the directory if it doesn't already exist

cd $ARCHIVEDIR 
  echo "url;logfile;path_html;timestamp" > wget_summary_test.csv

cd ..

xsv select url,normalized_url_hash $1 |
  xsv behead |
  while read line; do 
    url=$(echo $line | xsv select 1) # assigne variable for the url
    normalized_url_hash=$(echo $line | xsv select 2) # assigne variable for hash 
    logfile="${normalized_url_hash}_log"  # assign variable for log file
    timestamp=$(date +"%F %H:%M:%S") # assign variable for timestamp

    cd $ARCHIVEDIR  # go into the archive
      # do everything you need to do
      wget -E -H -k -K -p ${fakenews_url} -o ${index}_log
      pathsfile=$(cat ${index}_log | grep "Sauvegarde" | head -1 | tr '«' ',' | tr '»' ' ' | cut -d',' -f2)
  
      echo "${fakenews_url};${logfile};${pathsfile};${timestamp}" >> wget_summary_test.csv

    cd .. # go back to the top-level, where the script is saved / from where the script is deployed
    done