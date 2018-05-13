import os
import json
import requests

# Fetches the cities.geojson file, converts it to .poly format for osmconvert,
# and writes out a file with commands to use with parallel

resp = requests.get("https://raw.githubusercontent.com/nextzen/metro-extracts/master/cities.geojson")
resp.raise_for_status()

with open(os.path.join('/mnt/tmp', 'commands.txt'), 'w') as c:
    for feature in resp.json().get('features'):
        feature_id = feature['id']
        with open(os.path.join('/mnt/tmp', feature_id + '.poly'), 'w') as f:
            f.write(feature_id + '\n')
            for n, ring in enumerate(feature['geometry']['coordinates']):
                if n == 0:
                    # The first ring of a polygon is the "outer"
                    f.write('%s\n' % n)
                else:
                    # The .poly format requires the ! to 'subtract' the inner rings
                    f.write('!%s\n' % n)

                for ll in ring:
                    f.write('\t%0.6f\t%0.6f\n' % (ll[0], ll[1]))

                f.write("END\n")
            f.write("END\n")

        c.write(
            "osmconvert /mnt/planet/planet-latest.o5m "
                "--out-pbf "
                "-B=/mnt/tmp/{id}.poly "
                "--hash-memory=1500 "
                "--drop-broken-refs "
                "> /mnt/planet/{id}.osm.pbf"
            " && "
            "osmconvert /mnt/planet/{id}.osm.pbf "
                "--out-osm "
                "> /mnt/planet/{id}.osm "
            " && "
            "pbzip2 -f /mnt/planet/{id}.osm\n".format(
                id=feature_id,
            )
        )
