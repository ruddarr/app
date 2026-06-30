#!/usr/bin/env bash
#
# Copies a local (gitignored) seed-instances.json into the booted simulator's
# Ruddarr app container so the in-app "Seed Instances" button (DEBUG only, under
# Settings → Instances) can read it. Real credentials never enter the repo.
#
# Usage:
#   1. cp seed-instances.example.json seed-instances.json   # then fill in real creds
#   2. Boot a simulator and run a DEBUG build of Ruddarr (so its container exists)
#   3. ./scripts/seed-instances.sh
#   4. In the app: Settings → Seed Instances
#
# Pass a custom seed file as the first argument: ./scripts/seed-instances.sh path/to/seed.json
set -euo pipefail

BUNDLE_ID="com.ruddarr"
SEED_FILE="${1:-seed-instances.json}"

if [[ ! -f "$SEED_FILE" ]]; then
  echo "error: '$SEED_FILE' not found — copy seed-instances.example.json and add your credentials." >&2
  exit 1
fi

if ! CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null)"; then
  echo "error: could not find '$BUNDLE_ID' on the booted simulator — install/run a DEBUG build first." >&2
  exit 1
fi

DEST="$CONTAINER/Documents/seed-instances.json"
mkdir -p "$CONTAINER/Documents"
cp "$SEED_FILE" "$DEST"

echo "Copied '$SEED_FILE' → $DEST"
echo "Now tap Settings → Seed Instances in the app."
