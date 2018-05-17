import itertools
import os
import json

# Fetches the cities.geojson file, converts it to config for osmium-tool export

cities_path = os.path.join(os.path.dirname(__file__), 'cities.geojson')
with open(cities_path, 'r') as f:
    data = json.load(f)

def grouper(n, iterable):
    it = iter(iterable)
    while True:
       chunk = tuple(itertools.islice(it, n))
       if not chunk:
           return
       yield chunk

for n, feature_group in enumerate(grouper(5, data.get('features'))):
    config = {
        'directory': '/mnt/output',
        'extracts': []
    }

    for feature in feature_group:
        config['extracts'].append({
            'output': '%s.osm.pbf' % feature['id'],
            'polygon': feature['geometry']['coordinates'],
        })

    with open(os.path.join('/mnt/tmp', 'osmium-config.%03d.json' % n), 'w') as f:
        json.dump(config, f, indent=2)
