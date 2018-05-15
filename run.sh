#!/bin/bash
set -e
set -x

## Set up the system and mount point

sudo apt-get update -y && sudo apt-get upgrade -y
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

# Convert the planet to o5m
mkdir -p /mnt/logs
osmconvert /mnt/planet/planet-latest.osm.pbf \
    -o=/mnt/planet/planet-latest.o5m > /mnt/logs/osmconvert_planet.log 2>&1

# Generate extracts
sudo apt-get install -y pbzip2 parallel
cd /home/ubuntu
curl -L https://github.com/nextzen/metro-extracts/archive/master.tar.gz | tar -zx
mkdir -p /mnt/tmp /mnt/poly
python /home/ubuntu/metro-extracts-master/generate_osmconvert_commands.py

parallel --no-notice \
    -j 24 \
    -a /mnt/tmp/parallel_osmconvert_commands.txt \
    --joblog /mnt/logs/parallel_osmconvert.log

# Convert extracts to Shapefiles + GeoJSON
curl -L https://imposm.org/static/rel/imposm3-0.4.0dev-20170519-3f00374-linux-x86-64.tar.gz | tar -zx
sudo apt-get install -y jq osm2pgsql gdal-bin zip
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
aws s3 sync /mnt/output s3://metro-extracts.nextzen.org/$(cat /mnt/planet/planet-latest.osm.pbf.timestamp)
