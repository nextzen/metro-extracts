#!/bin/bash
set -e
slug=$1
prefix=${slug//-/_}

mkdir -p /mnt/shp/${slug}-imposm

/home/ubuntu/imposm3-0.4.0dev-20170519-3f00374-linux-x86-64/imposm3 import \
  -mapping /home/ubuntu/metro-extracts-master/mapping.json \
  -read /mnt/planet/${slug}.osm.pbf \
  -cachedir /mnt/shp/${slug}-imposm \
  -srid 4326 \
  -write \
  -connection postgis://osm:osm@localhost/osm?prefix=${prefix}_ \
  -deployproduction

declare -a arr=('admin' 'aeroways' 'amenities' 'buildings' 'landusages' 'landusages_gen0' 'landusages_gen1' 'places' 'roads' 'roads_gen0' 'roads_gen1' 'transport_areas' 'transport_points' 'waterareas' 'waterareas_gen0' 'waterareas_gen1' 'waterways')

for i in ${arr[@]}; do
  pgsql2shp \
    -rk \
    -f /mnt/shp/${slug}-imposm/${slug}_osm_${i}.shp \
    -h localhost -P osm -u osm osm \
    ${prefix}_${i}

  ogr2ogr \
    -lco ENCODING="UTF-8" \
    -f GeoJSON \
    -s_srs epsg:4326 \
    -t_srs crs:84 \
    /mnt/shp/${slug}-imposm/${slug}_${i}.geojson \
    /mnt/shp/${slug}-imposm/${slug}_osm_${i}.shp
done

zip -j /mnt/shp/${slug}.imposm-shapefiles.zip \
  /mnt/shp/${slug}-imposm/${slug}_osm_*.shp \
  /mnt/shp/${slug}-imposm/${slug}_osm_*.prj \
  /mnt/shp/${slug}-imposm/${slug}_osm_*.dbf \
  /mnt/shp/${slug}-imposm/${slug}_osm_*.shx
zip -j /mnt/shp/${slug}.imposm-geojson.zip \
  /mnt/shp/${slug}-imposm/${slug}_*.geojson

rm -r /mnt/shp/${slug}-imposm

for i in ${arr[@]}; do
  echo "DROP TABLE ${prefix}_${i} CASCADE" | psql postgresql://osm:osm@localhost/osm
done
