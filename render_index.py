import json
import os
from collections import defaultdict
from jinja2 import Environment, FileSystemLoader

THIS_DIR = os.path.dirname(os.path.abspath(__file__))

def render_html():
    j2_env = Environment(loader=FileSystemLoader(THIS_DIR),
                         trim_blocks=True)

    city_features = []
    with open("cities.geojson", "r") as f:
        city_features = json.load(f).get('features')

    feature_tree = defaultdict(lambda: defaultdict(dict))
    for f in city_features:
        region_name = f['properties']['region']
        country_name = f['properties']['country']
        metro_name = f['properties']['name']

        feature_tree[region_name][country_name][metro_name] = f

    return j2_env.get_template('map_template.html').render(
        feature_tree=feature_tree,
    )

if __name__ == '__main__':
    with open('index.html', 'w') as f:
        f.write(render_html())
