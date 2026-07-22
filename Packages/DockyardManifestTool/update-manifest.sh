#!/bin/sh
set -euo pipefail

# Hashing is on by default: GitHub's asset digest or the hash cached in the
# existing manifest.json is used when possible; DMGs are downloaded only for
# genuinely new releases.
swift run dockyard-manifest-tool build --config ../../../DockyardManifest/dockyard.config.json --output ../../../DockyardManifest/manifest.json
