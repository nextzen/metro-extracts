import json
import requests

# Converts the Mapzen metro extracts JSON array to a GeoJSON feature collection.
# Used once to import the original cities into this repository.

response = requests.get("https://raw.githubusercontent.com/mapzen/metro-extracts/master/cities.json")
response.raise_for_status()
cities = response.json()

def translate(obj):
    west, south, east, north = map(float, [
        obj['bbox']['left'],
        obj['bbox']['bottom'],
        obj['bbox']['right'],
        obj['bbox']['top']
    ])

    return {
        "type": "Feature",
        "id": obj["id"],
        "geometry": {
            "type": "Polygon",
            "coordinates":[[
                [west, south],
                [west, north],
                [east, north],
                [east, south],
                [west, south]
            ]]
        },
        "properties": {
            "name": obj['name'],
            "region": obj['region'],
            "country": obj['country']
        }
    }

feature_collection = {
    "type": "FeatureCollection",
    "features": [translate(o) for o in cities],
}

with open('cities.geojson', 'w') as out_f:
    json.dump(feature_collection, out_f, indent=4)
