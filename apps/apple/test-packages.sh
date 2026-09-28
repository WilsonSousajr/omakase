#!/usr/bin/env bash
# Runs each package's tests with coverage and gates it (spec: >= 90% on API
# and Store; Features' *View.swift excluded because SwiftUI view bodies are
# not meaningfully unit-testable - its models are measured).
set -euo pipefail
cd "$(dirname "$0")"
# Build products live outside the checkout (#134): in an iCloud-synced folder
# the File Provider tags each new .xctest bundle with FinderInfo, and
# codesign rejects it. ~/Library/Caches is never synced.
SCRATCH="${OMAKASE_SWIFTPM_SCRATCH:-$HOME/Library/Caches/omakase/swiftpm}"
for package in Packages/*/; do
  name=$(basename "$package")
  swift test --package-path "$package" --scratch-path "$SCRATCH/$name" --enable-code-coverage
  codecov=$(swift test --package-path "$package" --scratch-path "$SCRATCH/$name" --show-codecov-path)
  excludes=()
  [ "$name" = OmakaseFeatures ] && excludes=(--exclude View.swift)
  python3 tools/coverage_gate.py --codecov "$codecov" --package "$name" --threshold 90 ${excludes[@]+"${excludes[@]}"}
done
