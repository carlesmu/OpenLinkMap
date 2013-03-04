#!/bin/bash

# OpenLinkMap Copyright (C) 2010 Alexander Matheisen
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it under certain conditions.
# See http://wiki.openstreetmap.org/wiki/OpenLinkMap for details.


# working directory, please change
cd /usr/local/src/osm
PATH="$PATH:/var/www/openlinkmap/OpenLinkMap/import/bin"
export JAVACMD_OPTIONS=-Xmx2800M


# download planet file, ~ 8 hours
#echo "Downloading planet file"
#echo ""
#wget http://planet.openstreetmap.org/pbf/planet-latest.osm.pbf
#mv planet-latest.osm.pbf old.pbf
#echo ""

# download benelux 
if [ ! -f old.pbf ]; then
   echo "Downloading belgium file"
   echo ""
   wget http://planet.openstreetmap.nl/benelux/planet-benelux-130304.osm.pbf
   mv planet-benelux-130304.osm.pbf old.pbf
   echo ""
fi

## update planet file
#echo "Updating planet file"
#echo ""
#date -u +%s > timestamp
#osmupdate old.pbf new.pbf --max-merge=2 --hourly --drop-author -v
#rm old.pbf
#mv new.pbf old.pbf
#echo ""


if [ ! -f temp.o5m ]; then
   # convert planet file, ~ 25 min
   echo "Converting  file"
   echo ""
   osmconvert old.pbf --drop-relations --drop-version --drop-author --out-o5m >temp.o5m
   echo ""
fi


# filter planet file, ~ 35 min
echo "Filtering file"
echo ""
osmfilter temp.o5m --keep="wikipedia= wikipedia:*= contact:phone= website= url= phone= fax= email= addr:email= image= url:official= contact:website= addr:phone= phone:mobile= contact:mobile= addr:fax= contact:email= contact:fax= image:panorama= opening_hours=" --out-o5m >temp-olm.o5m

osmfilter temp.o5m --keep="amenity=bus_station highway=bus_stop railway=station railway=halt railway=tram_stop amenity=parking" --out-o5m >temp-nextobjects.o5m
rm temp.o5m
echo ""


# create centroids, remove not-node elements, ~ 2 min
echo "Creating centroids, removing elements"
echo ""
osmconvert temp-olm.o5m --all-to-nodes --max-objects=90000000 --out-o5m >temp.o5m
rm temp-olm.o5m
osmfilter temp.o5m --drop-relations --drop-ways --keep-nodes="wikipedia= wikipedia:*= contact:phone= website= url= phone= fax= email= addr:email= image= url:official= contact:website= addr:phone= phone:mobile= contact:mobile= addr:fax= contact:email= contact:fax= image:panorama= opening_hours=" --out-o5m >temp-olm.o5m
rm temp.o5m
osmconvert temp-olm.o5m --fake-lonlat --fake-author --out-pbf >temp.pbf
rm temp-olm.o5m
osmosis-0.42/bin/osmosis --rb file="temp.pbf" --s --wb file="old-olm.pbf" omitmetadata="true"
rm temp.pbf
osmconvert old-olm.pbf --drop-author --out-osm >old-olm.osm
rm old-olm.pbf

osmconvert temp-nextobjects.o5m --all-to-nodes --max-objects=90000000 --out-o5m >temp.o5m
rm temp-nextobjects.o5m
osmfilter temp.o5m --drop-relations --drop-ways --keep-nodes="amenity=bus_station highway=bus_stop railway=station railway=halt railway=tram_stop amenity=parking" --out-o5m >temp-nextobjects.o5m
rm temp.o5m
osmconvert temp-nextobjects.o5m --fake-lonlat --fake-author --out-pbf >temp.pbf
rm temp-nextobjects.o5m
osmosis-0.42/bin/osmosis --rb file="temp.pbf" --s --wb file="old-nextobjects.pbf" omitmetadata="true"
rm temp.pbf
osmconvert old-nextobjects.pbf --drop-author --out-osm >old-nextobjects.osm
rm old-nextobjects.pbf
echo ""


# importing in database, ~ 20 min
echo "Importing in database"
echo ""
php import.php
osmconvert old-olm.osm --drop-author --out-o5m >old-olm.o5m
rm old-olm.osm
osmconvert old-nextobjects.osm --drop-author --out-o5m >old-nextobjects.o5m
rm old-nextobjects.osm
echo ""
