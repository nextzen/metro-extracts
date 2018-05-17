import argparse
import json
import os
import sys

# Build a GeoJSON with links + sizes for all the files we generate so that we can show it on a map

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = '/mnt/output'
KEY_PATTERNS = {
    "imposm-geojson.zip": "Imposm GeoJSON",
    "imposm-shapefiles.zip": "Imposm Shapefiles",
    "land.coastline.zip": "Land Coastline",
    "water.coastline.zip": "Water Coastline",
    "osm.bz2": "Raw OSM (bz2 compressed)",
    "osm.pbf": "Raw OSM (as PBF)",
    "osm2pgsql-geojson.zip": "osm2pgsql GeoJSON",
    "osm2pgsql-shapefiles.zip": "osm2pgsql Shapefiles",
}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('s3_url_prefix', help="The S3 URL prefix for links e.g. https://s3.amazonaws.com/bucket/planet_timestamp/")
    args = parser.parse_args()

    with open(os.path.join(THIS_DIR, "cities.geojson"), "r") as f:
        data = json.load(f).get('features')

    with open('/mnt/planet/planet-latest.osm.pbf.timestamp', 'r') as f:
        planet_timestamp = f.read().strip()

    output = {
        'type': "FeatureCollection",
        'planet_timestamp': planet_timestamp,
        'features': [],
    }

    def item(feature_id, file_suffix):
        path = os.path.join(OUTPUT_DIR, '%s.%s' % (feature_id, file_suffix))
        result = os.stat(path)

        return {
            'size': results.st_size,
            'url': '{s3_prefix}{feature_id}.{suffix}'.format(
                s3_prefix=args.s3_url_prefix,
                feature_id=feature_id,
                suffix=file_suffix,
            )
        }

    for feature in data.get('features'):
        feature_id = feature['id']

        out_feature = feature.copy()
        out_feature['properties'].update(dict(
            (suffix, item(feature_id, suffix))
            for suffix in KEY_PATTERNS.keys()
        ))
        output['features'].append(out_feature)

    json.dump(output, sys.stdout)
