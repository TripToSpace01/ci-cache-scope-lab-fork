#!/bin/sh
# Attacker-controlled build script (benign marker only, no secrets, no network).
# In the real scenario this file comes from the PR head commit that the
# cache-writer workflow checks out and executes.
set -eu
mkdir -p dist
sha="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
echo "POISONED-${sha}" > dist/marker.txt
cat > dist/run.sh <<'EOF'
#!/bin/sh
echo "attacker-controlled build output executed in the release job"
cat "$(dirname "$0")/marker.txt"
EOF
chmod +x dist/run.sh
echo "built $(cat dist/marker.txt)"
# t4 retrigger (comment only)
