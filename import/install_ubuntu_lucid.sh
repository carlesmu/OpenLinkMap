#!/bin/bash

# OpenLinkMap Copyright (C) 2010 Alexander Matheisen
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it under certain conditions.
# See http://wiki.openstreetmap.org/wiki/OpenLinkMap for details.


# run this script not automatically! you have to change paths and modify it to your own environment!

# Ubuntu Lucid (32/64 bit) version by glenn byte-consult be
CC=/usr/bin/gcc

# install necessary software for lucid
apt-get update && apt-get install gzip liblz0 postgresql-8.4 php5-geoip postgresql-8.4-postgis postgis postgresql-contrib-8.4

# (dpkg does all that for us, just need to reload php-fpm or apache for it to work)
# pecl install geoip
# add extension=geoip.so to php.ini 
# see  http://dev.maxmind.com/geoip/geolite

if [ ! -e /usr/share/GeoIP ]; then
 mkdir /usr/share/GeoIP
fi

cd /usr/share/GeoIP

# clean up first so we unpack the latest one, and not the first one ever downloaded
rm -Rf /usr/share/GeoIP/GeoIP.dat.g*
rm -Rf /usr/share/GeoIP/GeoLiteCity.dat.g*

# Since they seem to block based on user agents of curl/wget, keep them happy with some mac user agent, if not you will get 404
# country
wget --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30"  http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz
gunzip GeoIP.dat.gz

# cities
wget --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_6_8) AppleWebKit/534.30 (KHTML, like Gecko) Chrome/12.0.742.112 Safari/534.30"  http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
gunzip GeoLiteCity.dat.gz
mv GeoLiteCity.dat GeoIPCity.dat

echo "Compiling tools"
wget -O - http://m.m.i24.cc/osmupdate.c | $CC -x c - -o osmupdate
wget -O - http://m.m.i24.cc/osmfilter.c | $CC -x c - -o osmfilter
wget -O - http://m.m.i24.cc/osmconvert.c | $CC -x c - -lz -o osmconvert

echo "Installing osmosis"
if [ -d /usr/share/GeoIP/osmosis ] ; then
 # cleaning old stuff
 rm -Rf /usr/share/GeoIP/osmosis
fi

mkdir -p /usr/share/GeoIP/osmosis
cd /usr/share/GeoIP/osmosis
wget -O - http://bretth.dev.openstreetmap.org/osmosis-build/osmosis-latest.tgz | tar xz

cd /usr/share/GeoIP/

# old default
CONTRIB_DIR="/usr/share/pgsql/contrib/"
if [ -d "/usr/share/postgresql/8.4/contrib/" ]; then
  # ubuntu default (using packages)
  CONTRIB_DIR="/usr/share/postgresql/8.4/contrib/"
else
  if [ ! -d $CONTRIB_DIR ]; then
    echo "Need to know the posgis contrib dir"
    exit;
  fi
fi

MACHINE_TYPE=`uname -m`
if [ ${MACHINE_TYPE} == 'x86_64' ]; then
  # 64-bit stuff here
  echo "64 bit"
  POSTGIS="${CONTRIB_DIR}postgis-64.sql"
else
  echo "32 bit"
  # 32-bit stuff here
  POSTGIS="${CONTRIB_DIR}postgis.sql"
fi

POSTSPATIAL="${CONTRIB_DIR}spatial_ref_sys.sql"
POSTHSTORE="${CONTRIB_DIR}hstore.sql"
POSTINT="${CONTRIB_DIR}_int.sql"

# set up database
echo "Creating user/db/lang..."
su -l postgres -c 'createuser -d -r -S olm'
su -l postgres -c 'createdb -E UTF8 -O olm olm'
su -l postgres -c 'createlang plpgsql olm'

if [ ! -f $POSTGIS ]; then
  echo "Post gis contrib not found"
  exit
fi

if [ ! -f $POSTSPATIAL ]; then
  echo "Post spatial contrib not found"
  exit
fi

if [ ! -f $POSTINT ]; then
  echo "Post int contrib not found"
  exit
fi

if [ ! -f $POSTHSTORE ]; then
  echo "Post hstore contrib not found"
  exit
fi

echo "Spatializing..."
su -l postgres -c "psql -d olm -f $POSTGIS"
su -l postgres -c "psql -d olm -f $POSTSPATIAL"
su -l postgres -c "psql -d olm -f $POSTHSTORE"
su -l postgres -c "psql -d olm -f $POSTINT"

echo "ALTER TABLE geometry_columns OWNER TO olm; ALTER TABLE spatial_ref_sys OWNER TO olm;"  | su -l postgres -c 'psql -d olm'
echo "ALTER TABLE geography_columns OWNER TO olm;"  | su -l postgres -c 'psql -d olm'

su -l postgres -c 'createdb -E UTF8 -O olm nextobjects'
su -l postgres -c 'createlang plpgsql nextobjects'

echo "Spatializing..."
su -l postgres -c "psql -d nextobjects -f $POSTGIS"
su -l postgres -c "psql -d nextobjects -f $POSTSPATIAL"
su -l postgres -c "psql -d nextobjects -f $POSTHSTORE"
su -l postgres -c "psql -d nextobjects -f $POSTINT"

echo "ALTER TABLE geometry_columns OWNER TO olm; ALTER TABLE spatial_ref_sys OWNER TO olm;"  | su -l postgres -c 'psql -d nextobjects'
echo "ALTER TABLE geography_columns OWNER TO olm;"  | su -l postgres -c 'psql -d nextobjects'

# database olm
echo "CREATE TABLE nodes (id bigint, tags hstore);" | su -l postgres -c 'psql -d olm'
echo "SELECT AddGeometryColumn('nodes', 'geom', 4326, 'POINT', 2);" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX geom_index_nodes ON nodes USING GIST(geom);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER nodes USING geom_index_nodes;" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX id_index_nodes ON nodes (id);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER nodes USING id_index_nodes;" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX tag_index_nodes ON nodes USING GIST (tags);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER nodes USING tag_index_nodes;" | su -l postgres -c 'psql -d olm'

echo "CREATE TABLE ways (id bigint, tags hstore);" | su -l postgres -c 'psql -d olm'
echo "SELECT AddGeometryColumn('ways', 'geom', 4326, 'POINT', 2);" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX geom_index_ways ON ways USING GIST(geom);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER ways USING geom_index_ways;" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX id_index_ways ON ways (id);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER ways USING id_index_ways;" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX tag_index_ways ON ways USING GIST (tags);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER ways USING tag_index_ways;" | su -l postgres -c 'psql -d olm'

echo "CREATE TABLE relations (id bigint, tags hstore);" | su -l postgres -c 'psql -d olm'
echo "SELECT AddGeometryColumn('relations', 'geom', 4326, 'POINT', 2);" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX geom_index_relations ON relations USING GIST(geom);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER relations USING geom_index_relations;" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX id_index_relations ON relations (id);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER relations USING id_index_relations;" | su -l postgres -c 'psql -d olm'
echo "CREATE INDEX tag_index_relations ON relations USING GIST (tags);" | su -l postgres -c 'psql -d olm'
echo "CLUSTER relations USING tag_index_relations;" | su -l postgres -c 'psql -d olm'

echo "GRANT all ON nodes TO olm;" | su -l postgres -c 'psql -d olm'
echo "GRANT all ON ways TO olm;" | su -l postgres -c 'psql -d olm'
echo "GRANT all ON relations TO olm;" | su -l postgres -c 'psql -d olm'

echo "GRANT truncate ON nodes TO olm;" | su -l postgres -c 'psql -d olm'
echo "GRANT truncate ON ways TO olm;" | su -l postgres -c 'psql -d olm'
echo "GRANT truncate ON relations TO olm;" | su -l postgres -c 'psql -d olm'

echo "ALTER TABLE nodes OWNER TO olm;" | su -l postgres -c 'psql -d olm'
echo "ALTER TABLE ways OWNER TO olm;" | su -l postgres -c 'psql -d olm'
echo "ALTER TABLE relations OWNER TO olm;" | su -l postgres -c 'psql -d olm'


# database nextobjects
echo "CREATE TABLE nodes (id bigint, tags hstore);" | su -l postgres -c 'psql -d nextobjects'
echo "SELECT AddGeometryColumn('nodes', 'geom', 4326, 'POINT', 2);" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX geom_index_nodes ON nodes USING GIST(geom);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER nodes USING geom_index_nodes;" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX id_index_nodes ON nodes (id);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER nodes USING id_index_nodes;" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX tag_index_nodes ON nodes USING GIST (tags);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER nodes USING tag_index_nodes;" | su -l postgres -c 'psql -d nextobjects'

echo "CREATE TABLE ways (id bigint, tags hstore);" | su -l postgres -c 'psql -d nextobjects'
echo "SELECT AddGeometryColumn('ways', 'geom', 4326, 'POINT', 2);" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX geom_index_ways ON ways USING GIST(geom);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER ways USING geom_index_ways;" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX id_index_ways ON ways (id);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER ways USING id_index_ways;" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX tag_index_ways ON ways USING GIST (tags);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER ways USING tag_index_ways;" | su -l postgres -c 'psql -d nextobjects'

echo "CREATE TABLE relations (id bigint, tags hstore);" | su -l postgres -c 'psql -d nextobjects'
echo "SELECT AddGeometryColumn('relations', 'geom', 4326, 'POINT', 2);" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX geom_index_relations ON relations USING GIST(geom);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER relations USING geom_index_relations;" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX id_index_relations ON relations (id);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER relations USING id_index_relations;" | su -l postgres -c 'psql -d nextobjects'
echo "CREATE INDEX tag_index_relations ON relations USING GIST (tags);" | su -l postgres -c 'psql -d nextobjects'
echo "CLUSTER relations USING tag_index_relations;" | su -l postgres -c 'psql -d nextobjects'

echo "GRANT all ON nodes TO olm;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT all ON ways TO olm;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT all ON relations TO olm;" | su -l postgres -c 'psql -d nextobjects'

echo "GRANT truncate ON nodes TO olm;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT truncate ON ways TO olm;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT truncate ON relations TO olm;" | su -l postgres -c 'psql -d nextobjects'

echo "ALTER TABLE nodes OWNER TO olm;" | su -l postgres -c 'psql -d nextobjects'
echo "ALTER TABLE ways OWNER TO olm;" | su -l postgres -c 'psql -d nextobjects'
echo "ALTER TABLE relations OWNER TO olm;" | su -l postgres -c 'psql -d nextobjects'


# access
echo "CREATE ROLE apache;" | su -l postgres -c 'psql -d olm'

echo "GRANT SELECT ON nodes TO apache;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT SELECT ON ways TO apache;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT SELECT ON relations TO apache;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT SELECT ON nodes TO apache;" | su -l postgres -c 'psql -d olm'
echo "GRANT SELECT ON ways TO apache;" | su -l postgres -c 'psql -d olm'
echo "GRANT SELECT ON relations TO apache;" | su -l postgres -c 'psql -d olm'

echo "CREATE ROLE w3_user1;" | su -l postgres -c 'psql -d olm'

echo "GRANT SELECT ON nodes TO w3_user1;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT SELECT ON ways TO w3_user1;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT SELECT ON relations TO w3_user1;" | su -l postgres -c 'psql -d nextobjects'
echo "GRANT SELECT ON nodes TO w3_user1;" | su -l postgres -c 'psql -d olm'
echo "GRANT SELECT ON ways TO w3_user1;" | su -l postgres -c 'psql -d olm'
echo "GRANT SELECT ON relations TO w3_user1;" | su -l postgres -c 'psql -d olm'
