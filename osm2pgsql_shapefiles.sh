#!/bin/bash
set -e
slug=$1
prefix=${slug//-/_}_osm

# generate shp files
#
osm2pgsql -sluc \
  --hstore \
  -C 2048 \
  -S /home/ubuntu/metro-extracts-master/osm2pgsql.style \
  -p ${prefix} \
  --number-processes 2 \
  -d ubuntu \
  /mnt/planet/${slug}.osm.pbf

pgsql2shp -rk \
  -f /mnt/shp/${slug}_osm_point.shp \
  ubuntu \
  ${prefix}_point
pgsql2shp -rk \
  -f /mnt/shp/${slug}_osm_polygon.shp \
  ubuntu \
  ${prefix}_polygon
pgsql2shp -rk \
  -f /mnt/shp/${slug}_osm_line.shp \
  ubuntu \
  ${prefix}_line

# generate geojson from shp files
#
ogr2ogr \
  -lco ENCODING="UTF-8" \
  -f GeoJSON \
  -t_srs crs:84 \
  /mnt/shp/${slug}_osm_line.geojson \
  /mnt/shp/${slug}_osm_line.shp
ogr2ogr \
  -lco ENCODING="UTF-8" \
  -f GeoJSON \
  -t_srs crs:84 \
  /mnt/shp/${slug}_osm_point.geojson \
  /mnt/shp/${slug}_osm_point.shp
ogr2ogr \
  -lco ENCODING="UTF-8" \
  -f GeoJSON \
  -t_srs crs:84 \
  /mnt/shp/${slug}_osm_polygon.geojson \
  /mnt/shp/${slug}_osm_polygon.shp

# zip up our output
#
zip -j \
  /mnt/shp/${slug}.osm2pgsql-shapefiles.zip \
  /mnt/shp/${slug}_osm_*.shp \
  /mnt/shp/${slug}_osm_*.prj \
  /mnt/shp/${slug}_osm_*.dbf \
  /mnt/shp/${slug}_osm_*.shx
zip -j \
  /mnt/shp/${slug}.osm2pgsql-geojson.zip \
  /mnt/shp/${slug}_osm_*.geojson

# remove source files
#
rm /mnt/shp/${slug}_osm_*.*

# clean up the db
#
echo "DROP TABLE ${prefix}_line"    | psql -d ubuntu
echo "DROP TABLE ${prefix}_nodes"   | psql -d ubuntu
echo "DROP TABLE ${prefix}_point"   | psql -d ubuntu
echo "DROP TABLE ${prefix}_polygon" | psql -d ubuntu
echo "DROP TABLE ${prefix}_rels"    | psql -d ubuntu
echo "DROP TABLE ${prefix}_roads"   | psql -d ubuntu
echo "DROP TABLE ${prefix}_ways"    | psql -d ubuntu
