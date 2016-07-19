#!/bin/bash 
#bash elasticsearch note indexer
#
#variables

#mapping for es put this into your index that you set below

# { "mappings": { "note" : { "properties": {"title": {"type": "string", "index": "not_analyzed"}, "body": {"type": "string", "index": "not_analyzed"},"author": {"type": "string", "index": "not_analyzed"}, "tags" : {"type": "string", "index": "not_analyzed"}, "note_date" : {"type": "date", "format": "epoch_second" }}}}}

#variables for use by the script
url=http://localhost:9200
index=notes_es
type=note
author=robert
editor_cmd=vim
tmpfile=/tmp/es_note.txt

#python one linerish thing for json escaping
jsonescape()
{
python -c '
import json,sys
print json.dumps(file.read(sys.stdin))
'
}

#this whole thing deals with the unlikely event you have an old temp file alread
#this would normally only happen if something went wrong last time
if [ -f $tmpfile ]; then
read -p " hey you're old temp file is here for some reason. Delete it? y/n" ans
   if [ $ans = "y" ]; then
       rm $tmpfile
   fi
fi


#start an editor (vim4lyfe)
$editor_cmd $tmpfile

read -p "enter tags seperated by commas 
" tags

#turn your line of csv tags entered into quoted stuff for json
listOtags=$(echo $tags|sed 's/,$//g; s/,/","/g; s/^/"/; s/$/"/')

#id will be the date in seconds since epoch
id=`date "+%s"`

#make json objects for each field
author_json="\"author\":\"$author\"" 
#the title is the top line of the file
title_json="\"title\": $(head -n 1 $tmpfile |jsonescape)"
body_json="\"body\": $(cat $tmpfile |jsonescape)"
date_json="\"note_date\": $id"
tags_json="\"tags\": [ $listOtags ] "

#assemble them to json object stored as a variable
payload="{ $author_json, $body_json, $date_json,$title_json, $tags_json}"

#build this lazy variable here
query="$url/$index/$type/$id"


#version with tee for debugging
esOutput="$(echo $payload |curl -i -XPUT $query -d  @- -s |tee curl.log |grep -o Created )"


#check the output and make it it has a 201 created returned
#note since we are evaluating the output of a query that indexes data, this is the magic point where we shove stuff into es
#esOutput="$(echo $payload |curl -i -XPUT $query -d  @- -s |grep -o Created )"


#if the file was indexed go ahead and delete it,
#if something went wrong alert the user and give them the id and file path 
#that way they can troubleshoot es and know where their data is
if [ "$esOutput" = "Created" ]; then
   rm $tmpfile
   echo "success"
else
echo "something went wrong, 
your file doesnt look like it was indexed 
check its id of $id 
Your file willn ot be auto-removed it is in $tmpfile"
fi
