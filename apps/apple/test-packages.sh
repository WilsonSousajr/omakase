#!/usr/bin/env bash
# Runs each package's tests with coverage and gates it (spec: >= 90% on API
# and Store; Features' *View.swift excluded because SwiftUI view bodies are
# not meaningfully unit-testable - its models are measured).
set -euo pipefail
cd "$(dirname "$0")"
for package in Packages/*/; do
  name=$(basename "$package")
  swift test --package-path "$package" --enable-code-coverage
  codecov=$(swift test --package-path "$package" --show-codecov-path)
  excludes=()
  [ "$name" = OmakaseFeatures ] && excludes=(--exclude View.swift)
  python3 tools/coverage_gate.py --codecov "$codecov" --package "$name" --threshold 90 ${excludes[@]+"${excludes[@]}"}
done
