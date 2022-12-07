#!/bin/bash

DATAFILE=$1  # CSV containing columns "url" and "normalized_url_hash"
ARCHIVEDIR=$2  # Directory in which the archive will be created

mkdir -p $ARCHIVEDIR  # Make the directory if it doesn't already exist

xsv select url,normalized_url_hash $1 |
  xsv behead |
  while read line; do 
    url=$(echo $line | xsv select 1) # assigne variable for the url
    normalized_url_hash=$(echo $line | xsv select 2) # assigne variable for hash 
    logfile="${normalized_url_hash}_log"  # assign variable for log file
    #pathsfile="${normalized_url_hash}_paths"  # assign variable for path file
    # timestamp=$(date +"%F %H:%M:%S") # assign variable for timestamp --> not usefull because already the first line of the logfile

    cd $ARCHIVEDIR  # go into the archive
      # do everything you need to do
      wget -E -H -k -K -p ${url} -o ${normalized_url_hash}_log
      main_pathfile=$(cat ${normalized_url_hash}_log | grep "Sauvegarde" | head -1 | tr '«' ',' | tr '»' ' ' | cut -d',' -f2)  
      echo "url: ${url}" # url of the fake news 
      echo "logfile: ${logfile}" # hash 
      echo "path_html: ${main_pathfile}" # path of the saved html
      echo "timestamp:${timestamp}" # timestamp of the wget command 
      # echo "URL archived at: ${timestamp}" >> logfile 
      echo "" 
      cat ${normalized_url_hash}_log | grep "Sauvegarde" | tr '«' ',' | tr '»' ' ' | cut -d',' -f2 > ${normalized_url_hash}_paths

    cd .. # go back to the top-level, where the script is saved / from where the script is deployed
    done

# INPUT CSV : url,normalized_url_hash
# in the script : url,logfile,pathsfile,timestamp
# OUTPOUT CSV : url,timestamp_minet_fetch,normalised_url_hash,pathsfile,timestamps_wget

# tested and work on the url from de facto !!