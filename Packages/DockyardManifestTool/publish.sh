#!/bin/sh
set -euo pipefail

# Builds the manifest, prints a change summary, and commits + pushes it to the
# DockyardManifest repo in one step. Pass --dry-run to preview without
# committing; any extra arguments are forwarded to the publish command.
swift run dockyard-manifest-tool publish --manifest-repo ../../../DockyardManifest "$@"
