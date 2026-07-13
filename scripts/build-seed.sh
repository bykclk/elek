#!/usr/bin/env bash
# Rebuild the seed filter (tools/seed.bin) from tools/seed.txt using the Swift
# Binary Fuse builder. tools/seed.bin is our own hand-authored list, kept only as
# a byte-compatibility test fixture for the Worker's TS port (worker/test/verify.ts).
# The app no longer bundles or reads it — filtering happens on the resolver.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/tools/seedgen/seedgen"

swiftc -O \
  "$ROOT/tools/seedgen/BinaryFuseBuilder.swift" \
  "$ROOT/tools/seedgen/DomainListParser.swift" \
  "$ROOT/tools/seedgen/main.swift" \
  -o "$BIN"

"$BIN" "$ROOT/tools/seed.txt" "$ROOT/tools/seed.bin"
echo "Done: tools/seed.bin"
