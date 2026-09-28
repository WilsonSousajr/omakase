#!/usr/bin/env bash
# The Apple gate, step for step what CI's apple-gate job runs (#85).
# backend/tools/tests/test_gate_workflow.py fails if the two drift apart.
# Needs Xcode and the pinned tools on PATH (./install-tools.sh).
set -euo pipefail
cd "$(dirname "$0")"
swift format lint --strict --recursive Packages OmakaseMac
swiftlint lint --strict --quiet
./check-layers.sh
./test-packages.sh
xcodegen generate --quiet
xcodebuild -project Omakase.xcodeproj -scheme OmakaseMac -destination platform=macOS CODE_SIGNING_ALLOWED=NO -quiet build
