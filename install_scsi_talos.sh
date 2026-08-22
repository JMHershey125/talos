export SCHEMATIC_ID=$(curl -s -X POST --data-binary @schematic.yaml https://factory.talos.dev/schematics | jq -r '.id')
talosctl upgrade --image factory.talos.dev/metal-installer/${SCHEMATIC_ID}:v1.13.7
