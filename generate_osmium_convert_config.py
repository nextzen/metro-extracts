import os
import json

# Fetches the cities.geojson file, converts it to config for osmium-tool export

cities_path = os.path.join(os.path.dirname(__file__), 'cities.geojson')
with open(cities_path, 'r') as f:
    data = json.load(f)

config = {
    'directory': '/mnt/output',
    'extracts': []
}

for feature in data.get('features'):
    config['extracts'].append({
        'output': '%s.osm.pbf' % feature['id'],
        'polygon': feature['geometry']['coordinates'],
    })
    config['extracts'].append({
        'output': '%s.osm.bz2' % feature['id'],
        'polygon': feature['geometry']['coordinates'],
    })

with open(os.path.join('/mnt/tmp', 'osmium-config.json'), 'w') as f:
    json.dump(config, f, indent=2)
