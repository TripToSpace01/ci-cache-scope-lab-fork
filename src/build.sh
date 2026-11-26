#!/bin/sh
# Legit build: produces dist/ from the checked-out source.
set -eu
mkdir -p dist
sha="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
echo "legit-${sha}" > dist/marker.txt
printf '#!/bin/sh\necho "release output: %s"\n' "$(cat dist/marker.txt)" > dist/run.sh
chmod +x dist/run.sh
echo "built $(cat dist/marker.txt)"
