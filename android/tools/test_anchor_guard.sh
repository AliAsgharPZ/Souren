#!/usr/bin/env bash
# Owner B7: prove that INVALID dataset anchors actually fail the build.
# A tampered copy of the word lists (anchor pair broken) must make
# tools/build_dataset.py exit non-zero.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/tools" "$TMP/data"
cp tools/build_dataset.py "$TMP/tools/"
cp data/arabic_all.txt data/persian_all.txt data/supplement_fa.py "$TMP/data/"

# Break the FIRST anchor pair: swap the Arabic anchor word with its
# neighbour so (ابتدا at line 1) no longer matches the assertion.
python3 - "$TMP/data/arabic_all.txt" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().splitlines()
lines[0], lines[1] = lines[1], lines[0]
open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY

if (cd "$TMP" && python3 tools/build_dataset.py > /dev/null 2>&1); then
  echo "GUARD FAILED: a broken anchor pair did NOT fail the dataset build" >&2
  exit 1
fi

echo "OK: invalid dataset anchors fail the build (guard verified)"
