import argparse
import boto3
import json
import os
from collections import defaultdict
from jinja2 import Environment, FileSystemLoader

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
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


def render_html(s3_prefix=None):
    j2_env = Environment(loader=FileSystemLoader(THIS_DIR),
                         trim_blocks=True)

    city_features = []
    with open(os.path.join(THIS_DIR, "cities.geojson"), "r") as f:
        city_features = json.load(f).get('features')

    # List the S3 bucket and pull in the file size + timestamps
    client = boto3.client('s3')
    paginator = client.get_paginator('list_objects_v2')
    response_iterator = paginator.paginate(
        Bucket='metro-extracts.nextzen.org',
        Prefix=s3_prefix,
        Delimiter='/',
    )
    file_infos = defaultdict(lambda: defaultdict(dict))
    for page in response_iterator:
        for obj in page['Contents']:
            k = obj['Key']
            try:
                metro_id, filetype = k.split('.', 1)
            except ValueError:
                continue

            file_infos[metro_id][filetype] = {
                'last_modified': obj['LastModified'],
                'etag': obj['ETag'],
                'size': obj['Size'],
            }

    feature_tree = defaultdict(lambda: defaultdict(dict))
    for f in city_features:
        region_name = f['properties']['region']
        country_name = f['properties']['country']
        metro_name = f['properties']['name']

        feature_tree[region_name][country_name][metro_name] = f

    return j2_env.get_template('map_template.html').render(
        feature_tree=feature_tree,
        file_infos=file_infos,
        file_type_infos=KEY_PATTERNS,
        s3_prefix=s3_prefix or '',
    )

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--prefix', help="The S3 prefix to base the index.html on")
    args = parser.parse_args()

    with open('index.html', 'w') as f:
        f.write(render_html(args.prefix))
