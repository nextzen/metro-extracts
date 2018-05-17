#!/bin/bash
slug=$1
prefix=${slug//-/_}_osm

export PGPASSWORD=osm

# generate shp files
#
osm2pgsql -sluc \
  --hstore \
  -C 2048 \
  -S /home/ubuntu/metro-extracts-master/osm2pgsql.style \
  -p ${prefix} \
  --number-processes 2 \
  -H localhost -U osm -d osm \
  /mnt/output/${slug}.osm.pbf

pgsql2shp -rk \
  -f /mnt/shp/${slug}_osm_point.shp \
  -h localhost -P osm -u osm osm \
  ${prefix}_point
pgsql2shp -rk \
  -f /mnt/shp/${slug}_osm_polygon.shp \
  -h localhost -P osm -u osm osm \
  ${prefix}_polygon
pgsql2shp -rk \
  -f /mnt/shp/${slug}_osm_line.shp \
  -h localhost -P osm -u osm osm \
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
  /mnt/output/${slug}.osm2pgsql-shapefiles.zip \
  /mnt/shp/${slug}_osm_*.shp \
  /mnt/shp/${slug}_osm_*.prj \
  /mnt/shp/${slug}_osm_*.dbf \
  /mnt/shp/${slug}_osm_*.shx \
  /mnt/shp/${slug}_osm_*.cpg
zip -j \
  /mnt/output/${slug}.osm2pgsql-geojson.zip \
  /mnt/shp/${slug}_osm_*.geojson

# remove source files
#
rm /mnt/shp/${slug}_osm_*.*

# clean up the db
#
echo "DROP TABLE ${prefix}_line"    | psql postgresql://osm:osm@localhost/osm
echo "DROP TABLE ${prefix}_nodes"   | psql postgresql://osm:osm@localhost/osm
echo "DROP TABLE ${prefix}_point"   | psql postgresql://osm:osm@localhost/osm
echo "DROP TABLE ${prefix}_polygon" | psql postgresql://osm:osm@localhost/osm
echo "DROP TABLE ${prefix}_rels"    | psql postgresql://osm:osm@localhost/osm
echo "DROP TABLE ${prefix}_roads"   | psql postgresql://osm:osm@localhost/osm
echo "DROP TABLE ${prefix}_ways"    | psql postgresql://osm:osm@localhost/osm
