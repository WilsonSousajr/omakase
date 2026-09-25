#!/usr/bin/env bash
# Enforces Features -> Store -> API (spec, Structure): each package may depend
# only on the packages listed here, and on nothing outside the repo.
set -euo pipefail
cd "$(dirname "$0")/Packages"
allowed() {
  case "$1" in
    OmakaseAPI) echo "" ;;
    OmakaseStore) echo "OmakaseAPI" ;;
    OmakaseFeatures) echo "OmakaseStore" ;;
    *) echo "unknown package $1" >&2; exit 2 ;;
  esac
}
status=0
for manifest in */Package.swift; do
  package="${manifest%%/*}"
  declared=$(grep -oE '\.package\([^)]*\)' "$manifest" | grep -oE 'path: *"\.\./[A-Za-z]+"' | grep -oE '[A-Za-z]+"$' | tr -d '"' | sort | tr '\n' ' ' | xargs || true)
  remote=$(grep -cE '\.package\(url:' "$manifest" || true)
  expected=$(allowed "$package" | tr ' ' '\n' | sort | tr '\n' ' ' | xargs || true)
  if [ "$declared" != "$expected" ] || [ "$remote" != "0" ]; then
    echo "$package depends on [$declared] (+$remote remote); allowed: [$expected]"
    status=1
  fi
done
[ "$status" = 0 ] && echo "layers hold: Features -> Store -> API"
exit "$status"
