#!/bin/sh
set -euo pipefail

# Registers a new app repo in the authoring config and scaffolds its .dockyard/
# folder. Pass the repo as owner/repo, or run without arguments to be asked for
# it. Any extra arguments are forwarded to the add command, e.g.
#
#   ./add-app.sh apparata/widget-mac --force-scaffold
#   ./add-app.sh --scaffold-out ../../../widget-mac

CONFIG=${DOCKYARD_CONFIG:-../../../DockyardManifest/dockyard.config.json}

REPO=""
case "${1:-}" in
    "") ;;
    -*) ;;                  # only flags given; ask for the repo below
    *) REPO=$1; shift ;;
esac

if [ -z "$REPO" ]; then
    printf 'GitHub repo to add (owner/repo): '
    read -r REPO
fi

case "$REPO" in
    */*/*|/*|*/) echo "Expected owner/repo, got: $REPO" >&2; exit 1 ;;
    */*) ;;
    *) echo "Expected owner/repo, got: $REPO" >&2; exit 1 ;;
esac

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

swift run dockyard-manifest-tool add "$REPO" --config "$CONFIG" "$@" 2>&1 | tee "$LOG"

# Offer to reveal the scaffold, since the next step is copying it into the app repo.
SCAFFOLD=$(sed -n 's/^Scaffolded into \(.*\):$/\1/p' "$LOG" | tail -1)
if [ -n "$SCAFFOLD" ] && [ -t 0 ]; then
    printf 'Reveal %s in Finder? [y/N] ' "$SCAFFOLD"
    read -r ANSWER
    case "$ANSWER" in
        [Yy]*) open "$SCAFFOLD" ;;
    esac
fi
