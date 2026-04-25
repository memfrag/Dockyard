#!/bin/sh
set -euo pipefail

swift run dockyard-manifest-tool build --config ../../../DockyardManifest/dockyard.config.json --output ../../../DockyardManifest/manifest.json --hash
