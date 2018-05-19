import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from jinja2 import Environment, FileSystemLoader

# Pipe a geojson index created by `generate_geojson_index.py` to this script
# and it will write an HTML index doc back to stdout.

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
KEY_PATTERNS = {
    "imposm-geojson.zip":       "Imposm GeoJSON",
    "imposm-shapefiles.zip":    "Imposm Shapefiles",
    "land.coastline.zip":       "Land Coastline",
    "water.coastline.zip":      "Water Coastline",
    "osm.bz2":                  "Raw OSM (bz2 compressed)",
    "osm.pbf":                  "Raw OSM (as PBF)",
    "osm2pgsql-geojson.zip":    "osm2pgsql GeoJSON",
    "osm2pgsql-shapefiles.zip": "osm2pgsql Shapefiles",
}

def render_html(data):
    city_features = data.get('features')

    feature_tree = defaultdict(lambda: defaultdict(dict))
    for f in city_features:
        region_name = f['properties']['region']
        country_name = f['properties']['country']
        metro_name = f['properties']['name']

        feature_tree[region_name][country_name][metro_name] = f

    j2_env = Environment(loader=FileSystemLoader(THIS_DIR),
                         trim_blocks=True)

    return j2_env.get_template('map_template.html').render(
        planet_timestamp=data.get('planet_timestamp'),
        feature_tree=feature_tree,
        file_type_infos=KEY_PATTERNS,
    )

if __name__ == '__main__':

    data = json.load(sys.stdin)

    sys.stdout.write(render_html(data))
