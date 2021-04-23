#!/bin/bash
export_db="keep.db"
sqplex="/opt/plexsql/PMS --sqlite"

$sqplex "$export_db" ".headers off" "SELECT id FROM metadata_items WHERE metadata_type = 15" > export_id.txt
#echo $export_id
export_id=($(cat export_id.txt))
#export_id=1359083
for j in "${export_id[@]}"; do   
   foldername=$($sqplex "$export_db" "SELECT account_id FROM metadata_item_accounts WHERE metadata_item_id = ${j};")
   if [ ! -z "$foldername" ]; then
     mkdir -p "$foldername"
     filename=$($sqplex "$export_db" "SELECT title_sort FROM metadata_items WHERE metadata_type = 15 AND id = ${j};" | sed 's/ /./g' | sed 's/[^A-Za-z0-9._-]//g')
     echo $filename
     $sqplex "$export_db" ".headers on" ".mode line" "SELECT id, guid, media_item_count, title, title_sort, duration, extra_data FROM metadata_items WHERE metadata_type = 15 AND id = ${j};" | sed -e 's/^[ \t]*//' | sed 's/= /\= \"/g' | sed "s/'/''/g" | sed 's/$/\"/g' > "$foldername/$filename.sav"
     echo "account_id=$foldername" >> "$foldername/$filename.sav"
   
     declare -a rating_keys=($($sqplex "$export_db" ".headers off" "SELECT metadata_item_id FROM play_queue_generators WHERE playlist_id = ${j}"))
     #echo ${rating_keys[1]}
     printf "item_guid=( " >> "$foldername/$filename.sav"
     for k in "${!rating_keys[@]}"; do item_guid[$k]=$($sqplex "$export_db" "SELECT guid FROM metadata_items WHERE id = ${rating_keys[$k]};"); printf "\"${item_guid[$k]}\" "; done >> "$foldername/$filename.sav"
     printf ")\n" >> "$foldername/$filename.sav"
     #echo $lib_ids
     printf "lib_ids=( " >> "$foldername/$filename.sav"
     for k in "${!rating_keys[@]}"; do 
		lib_ids[$k]=$($sqplex "$export_db" "SELECT library_section_id FROM metadata_items WHERE id = ${rating_keys[$k]};")
		#lib_names[$k]=$($sqplex "$export_db" "SELECT name FROM library_sections WHERE id = ${lib_ids[$k]};")
		printf "\"${lib_ids[$k]}\" "; done >> "$foldername/$filename.sav"
     printf ")\n" >> "$foldername/$filename.sav"
     sed -i 's/ = /=/g' "$foldername/$filename.sav"
   fi
done


#find -mindepth 1 -depth -exec rename 's{/\.([^\/]*$)}{/$1}' {} +
#find -mindepth 1 -depth -exec rename 's{/\.([^\/]*$)}{/$1}' {} +
rm export_id.txt
