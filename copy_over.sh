#!/bin/bash
start_time=`date +%s`
set -x #echo on
EPOC=`date +"%Y-%m-%d"`

plexdocker=$1
plexdb="/opt/${plexdocker}/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
sqplex="/opt/plexsql/PMS --sqlite"
plexbase="/opt/plex_db_backups/plexbase.db"

#make working directory
rm -rf "/opt/plex_db_backups/Databases/$plexdocker/"
mkdir -p "/opt/plex_db_backups/Databases/$plexdocker/"
#make backups directory
mkdir -p "/opt/plex_db_backups/$plexdocker/"

docker stop $plexdocker
#make backups then resume plex during background operations
echo "Copying $plexdocker db and preferences file to /opt/plex_db_backups/$plexdocker/"
cp -RL "/opt/$plexdocker/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" "/opt/plex_db_backups/$plexdocker/com.plexapp.plugins.library.db+$EPOC"
cp "/opt/$plexdocker/Library/Application Support/Plex Media Server/Preferences.xml" "/opt/plex_db_backups/$plexdocker/Preferences.xml+$EPOC"
docker start $plexdocker

#transferring $plexdocker

cd "/opt/plex_db_backups/Databases/$plexdocker/"
cp "/opt/plex_db_backups/$plexdocker/com.plexapp.plugins.library.db+$EPOC" keep.db

/opt/plex_db_backups/export_pl.sh
echo ".dump metadata_item_settings" | $sqplex keep.db | grep -v TABLE | grep -v INDEX > metadata_item_settings.sql
echo ".dump metadata_item_views" | $sqplex keep.db | grep -v TABLE | grep -v INDEX > metadata_item_views.sql


$sqplex $plexbase "DELETE FROM metadata_item_views;"
$sqplex $plexbase "DELETE FROM metadata_item_settings;"
$sqplex $plexbase "DELETE FROM statistics_bandwidth;"
$sqplex $plexbase "DELETE FROM statistics_media;"
$sqplex $plexbase "DELETE FROM statistics_resources;"
$sqplex $plexbase "DELETE FROM accounts;"
$sqplex $plexbase "DELETE FROM devices;"
$sqplex $plexbase "DELETE FROM play_queue_generators;"
$sqplex $plexbase "DELETE FROM metadata_item_accounts;"
$sqplex $plexbase "DELETE FROM metadata_items WHERE metadata_type = 15;"
$sqplex $plexbase "DROP INDEX index_title_sort_naturalsort;"

/opt/plex_db_backups/import_pl.sh

#merge plexbase with import_data
rm com.plexapp.plugins.library.db
cp $plexbase com.plexapp.plugins.library.db
cat metadata_item_settings.sql | $sqplex com.plexapp.plugins.library.db
cat metadata_item_views.sql | $sqplex com.plexapp.plugins.library.db
cat import_metadata_items.sql | $sqplex com.plexapp.plugins.library.db
cat import_metadata_item_accounts.sql | $sqplex com.plexapp.plugins.library.db
cat import_playq.sql | $sqplex com.plexapp.plugins.library.db

#go to db directory and import new db
cd "/opt/${plexdocker}/Library/Application Support/Plex Media Server/Plug-in Support/Databases/"

docker stop $plexdocker
mv com.plexapp.plugins.library.db com.plexapp.plugins.library.db.original
rm com.plexapp.plugins.library.db-shm
rm com.plexapp.plugins.library.db-wal
mv "/opt/plex_db_backups/Databases/$plexdocker/com.plexapp.plugins.library.db" com.plexapp.plugins.library.db
docker start $plexdocker

end_time="$(expr `date +%s` - $start_time)"
total_time=$(printf '%02d hr %02d min %02d secs\n' $((end_time/3600)) $((end_time%3600/60)) $((end_time%60)))
echo run time is $(expr `date +%s` - $start_time) seconds or $total_time
