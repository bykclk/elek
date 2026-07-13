#!/usr/bin/env bash
# Build the FULL Binary Fuse blocklist that the Worker serves, from HaGeZi.
#
# GPL note: HaGeZi's list is GPLv3. We do NOT commit the derived filter
# (worker/blocklist.bin is gitignored) — committing it to the public repo would
# be redistribution. Running it on our own resolver to answer DNS is "use", not
# "conveying" (GPLv3, unlike AGPL, is not triggered by network service), so
# generating it here at deploy time and letting wrangler embed it is fine.
#
# Reuses the exact Swift builder the app uses on-device, so the Worker's filter
# is byte-identical to what the app would build from the same list.
#
# usage: scripts/build-blocklist.sh [list-url]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORKER="$ROOT/worker"
LIST_URL="${1:-https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/light.txt}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching $LIST_URL ..."
curl -fsSL "$LIST_URL" -o "$TMP/list.txt"
echo "  $(grep -vc '^\s*#' "$TMP/list.txt") non-comment lines"

echo "Compiling the Swift Binary Fuse builder ..."
swiftc -O \
  "$ROOT/tools/seedgen/BinaryFuseBuilder.swift" \
  "$ROOT/tools/seedgen/DomainListParser.swift" \
  "$ROOT/tools/seedgen/main.swift" \
  -o "$TMP/buildfuse"

echo "Building worker/blocklist.bin ..."
"$TMP/buildfuse" "$TMP/list.txt" "$WORKER/blocklist.bin"
echo "Done: worker/blocklist.bin — $(wc -c < "$WORKER/blocklist.bin") bytes"
echo "Deploy with:  cd worker && npm run deploy"
