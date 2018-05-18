#!/bin/bash
set -e
set -x

## Set up the system and mount point

sudo apt-get update -y
sudo mkfs.xfs /dev/nvme1n1
sudo mkdir -p /mnt
sudo mount /dev/nvme1n1 /mnt
sudo chown -R ubuntu /mnt

## Install postgres

sudo apt-get install -y postgresql postgresql-contrib postgis

sudo pg_dropcluster --stop 9.5 main
mkdir -p /mnt/postgres
sudo pg_createcluster --start -d /mnt/postgres 9.5 main

# Adjust PostgreSQL configuration

sudo sed -i -e"s/^max_connections = 100.*$/max_connections = 200/" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i -e"s/^#autovacuum = on.*$/autovacuum = off/" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i -e"s/^shared_buffers = 128MB.*$/shared_buffers = 8GB/" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i -e"s/^#work_mem = 4MB.*$/work_mem = 64MB/" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i -e"s/^#temp_buffers = 8MB.*$/temp_buffers = 128MB/" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i -e"s/^#maintenance_work_mem = 64MB.*$/maintenance_work_mem = 512MB/" /etc/postgresql/9.5/main/postgresql.conf
sudo sed -i -e"s/^#maintenance_work_mem = 64MB.*$/maintenance_work_mem = 512MB/" /etc/postgresql/9.5/main/postgresql.conf
sudo service postgresql restart

# Add user and database

sudo -u postgres createuser --no-superuser --no-createrole --createdb osm
sudo -u postgres createdb -E UTF8 -O osm osm
sudo -u postgres psql -d osm -c "CREATE EXTENSION postgis;"
sudo -u postgres psql -d osm -c "CREATE EXTENSION hstore;"
sudo -u postgres psql -d osm -c "ALTER USER osm WITH PASSWORD 'osm';"

## Download the planet
mkdir -p /mnt/planet
wget --quiet \
    -O /mnt/planet/planet-latest.osm.pbf \
    https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf

sudo apt-get install -y osmctools

# Update the planet to the latest hour
osmupdate --day --hour \
    /mnt/planet/planet-latest.osm.pbf /mnt/planet/planet-latest-updated.osm.pbf \
&& rm /mnt/planet/planet-latest.osm.pbf \
&& mv /mnt/planet/planet-latest-updated.osm.pbf /mnt/planet/planet-latest.osm.pbf

date +%Y-%m-%d-%H-%M-%S --date=`osmconvert --out-timestamp /mnt/planet/planet-latest.osm.pbf` > \
    /mnt/planet/planet-latest.osm.pbf.timestamp

# Generate extracts
sudo apt-get install -y \
    libboost-program-options-dev \
    libboost-dev \
    libbz2-dev \
    zlib1g-dev \
    libexpat1-dev \
    build-essential \
    cmake
curl -L https://github.com/osmcode/libosmium/archive/v2.14.0.tar.gz | tar xz
mv libosmium-2.14.0 libosmium
curl -L https://github.com/mapbox/protozero/archive/v1.6.2.tar.gz | tar xz
mv protozero-1.6.2 protozero
curl -L https://github.com/osmcode/osmium-tool/archive/v1.8.0.tar.gz | tar xz
cd osmium-tool-1.8.0
mkdir build
cd build
cmake ..
make
sudo make install

cd /home/ubuntu
mkdir -p /mnt/tmp /mnt/output
python /home/ubuntu/metro-extracts-master/generate_osmium_export_config.py

for i in /mnt/tmp/osmium-config.*.json;
do
    osmium extract \
        --overwrite \
        --no-progress \
        --strategy=smart \
        --config $i \
        /mnt/planet/planet-latest.osm.pbf
done

# Convert extracts to Shapefiles + GeoJSON
curl -L https://imposm.org/static/rel/imposm3-0.4.0dev-20170519-3f00374-linux-x86-64.tar.gz | tar -zx
sudo apt-get install -y jq osm2pgsql gdal-bin zip parallel
mkdir -p /mnt/shp

jq -r .features[].id /home/ubuntu/metro-extracts-master/cities.geojson > /mnt/tmp/cities.txt

parallel --no-notice \
    -j 12 \
    -a /mnt/tmp/cities.txt \
    --joblog /mnt/logs/parallel_osm2pgsql_shapefiles.log \
    /home/ubuntu/metro-extracts-master/osm2pgsql_shapefiles.sh
parallel --no-notice \
    -j 12 \
    -a /mnt/tmp/cities.txt \
    --joblog /mnt/logs/parallel_imposm_shapefiles.log \
    /home/ubuntu/metro-extracts-master/imposm_shapefiles.sh

# Upload result to S3
sudo apt-get install -y awscli
s3prefix=$(date +%Y-%m-%d-%H-%M --date=`cat /mnt/planet/planet-latest.osm.pbf.timestamp`)
python metro-extracts-master/generate_geojson_index.py \
    "https://s3.amazonaws.com/metro-extracts.nextzen.org/${s3prefix}/" > /mnt/output/index.geojson
aws s3 sync \
    --metadata="OsmPlanetDate=`cat /mnt/planet/planet-latest.osm.pbf.timestamp | tr -d '\n'`" \
    --acl=public-read \
    /mnt/output \
    s3://metro-extracts.nextzen.org/$s3prefix
aws s3 sync \
    --acl=public-read \
    /mnt/output/index.geojson \
    s3://metro-extracts.nextzen.org/latest.geojson
