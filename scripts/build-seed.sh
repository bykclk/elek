#!/usr/bin/env bash
# Rebuild the bundled seed blocklist (Elek/Resources/blocklist.bin) from
# tools/seed.txt using the same Swift Binary Fuse builder the app uses on-device.
# Run this after editing tools/seed.txt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/tools/seedgen/seedgen"

swiftc -O \
  "$ROOT/Elek/BinaryFuseBuilder.swift" \
  "$ROOT/Elek/DomainListParser.swift" \
  "$ROOT/tools/seedgen/main.swift" \
  -o "$BIN"

"$BIN" "$ROOT/tools/seed.txt" "$ROOT/Elek/Resources/blocklist.bin"
echo "Done. Rebuild the app in Xcode to ship the new seed."
