import os
import json

# Fetches the cities.geojson file, converts it to .poly format for osmconvert,
# and writes out a file with commands to use with parallel

cities_path = os.path.join(os.path.dirname(__file__), 'cities.geojson')
with open(cities_path, 'r') as f:
    data = json.load(f)

with open(os.path.join('/mnt/tmp', 'parallel_osmconvert_commands.txt'), 'w') as c:
    for feature in data.get('features'):
        feature_id = feature['id']
        with open(os.path.join('/mnt/poly', feature_id + '.poly'), 'w') as f:
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
                "-B=/mnt/poly/{id}.poly "
                "--hash-memory=1500 "
                "--drop-broken-refs "
                "-t=/mnt/tmp/osmconvert_tempfile "
                "> /mnt/output/{id}.osm.pbf"
            " && "
            "osmconvert /mnt/output/{id}.osm.pbf "
                "--out-osm "
                "> /mnt/output/{id}.osm"
            " && "
            "pbzip2 -f /mnt/output/{id}.osm\n".format(
                id=feature_id,
            )
        )
