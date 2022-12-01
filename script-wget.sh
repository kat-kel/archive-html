#!/bin/bash

INPUTFILE = $1

 xsv select fakenews_url,index $1 |
   xsv behead | 
   while read line; do 
      url=$(echo $line | xsv select 1)
      id=$(echo $line | xsv select 2)
      wget -E -H -k -K -p $url -o log_$id
      cat log_$id |
      grep "Sauvegarde" |
      head -1 |
      tr '«' ',' |
      tr '»' ' ' |
      cut -d',' -f2 > /Users/ines.girard/Dev/archive-html/wget_df_test/name_archive/name_$id.csv
      done 

# Create the directory in which we want to store the archive ; "archive_html"
# Create another directory within "archive_htlm" to store for each url their path of html within a file named name_index ; "name_archive"
