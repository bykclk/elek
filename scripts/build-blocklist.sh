#!/usr/bin/env bash
# Download a HaGeZi domain list and regenerate Elek/Resources/blocklist.bin.
# Usage: scripts/build-blocklist.sh [list-name]
#   list-name defaults to "light"; try "pro", "pro.plus", "multi.pro", etc.
set -euo pipefail

LIST="${1:-light}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/filtergen/hagezi-${LIST}.txt"
OUT="$ROOT/Elek/Resources/blocklist.bin"
URL="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/${LIST}.txt"

echo "Downloading $URL"
curl -fsSL -o "$SRC" "$URL"

echo "Building $OUT"
( cd "$ROOT/filtergen" && go run . -in "$SRC" -out "$OUT" )

echo "Done. Rebuild the app in Xcode to ship the new blocklist."
