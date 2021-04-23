#!/bin/bash

#tv_lib=1
#mov_lib=4
sqplex="/opt/plexsql/PMS --sqlite"
plexbase="/opt/plex_db_backups/plexbase.db"

# Find last rows of each relevant table
last_row=$($sqplex $plexbase "SELECT MAX(id) FROM metadata_items;")
playlist_id=$((last_row+1))
last_row=$($sqplex $plexbase "SELECT MAX(id) FROM metadata_item_accounts;")
row_accounts=$((last_row+1))
last_row=$($sqplex $plexbase "SELECT MAX(id) FROM play_queue_generators;");
row_playq=$((last_row+1))

#create header sql import files
echo "PRAGMA foreign_keys=OFF;" | tee import_metadata_items.sql import_metadata_item_accounts.sql import_playq.sql
echo "BEGIN TRANSACTION;" | tee -a import_metadata_items.sql import_metadata_item_accounts.sql import_playq.sql


#Loop through each file in folder and add into sql import files

for f in **/*.sav
do
   . $f
   echo "INSERT INTO metadata_items VALUES($playlist_id,NULL,NULL,15,'$guid','$media_item_count','$title','$title_sort','','',NULL,NULL,'','',NULL,NULL,'',NULL,0,1,'$duration','','','','','','','','','','',NULL,NULL,NULL,NULL,NULL,'2021-03-17 06:59:21','2021-03-17 06:59:21','2021-03-17 07:03:25',NULL,'','','',NULL,NULL,NULL,NULL);" >> import_metadata_items.sql
   echo "INSERT INTO metadata_item_accounts VALUES($row_accounts,$account_id,$playlist_id);" >> import_metadata_item_accounts.sql
   for k in "${!item_guid[@]}"
   do
      lib_ids[$k]=$($sqplex "$export_db" "SELECT id FROM library_sections WHERE name = '${lib_names[$k]}';")
      ratingkey=$($sqplex $plexbase "SELECT id FROM metadata_items WHERE guid = '${item_guid[$k]}' AND (library_section_id = ${lib_ids[$k]});")
	  if [ ! -z "$ratingkey" ]; then
	    echo "INSERT INTO play_queue_generators VALUES($row_playq,$playlist_id,$ratingkey,'',NULL,NULL,$(((k+1)*1000)),'2021-03-17 06:59:21','2021-03-17 06:59:21',7596568095033486089,NULL,NULL,'');" >> import_playq.sql
	    let "row_playq++"
	  fi
   done
   let "playlist_id++"
   let "row_accounts++"
done



#create footer sql import files
echo "COMMIT;" | tee -a import_metadata_items.sql import_metadata_item_accounts.sql import_playq.sql
