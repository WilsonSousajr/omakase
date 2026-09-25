#!/usr/bin/env bash
# Installs the pinned SwiftLint and XcodeGen into apps/apple/.tools/bin.
# Usage: ./install-tools.sh && export PATH="$PWD/.tools/bin:$PATH"
set -euo pipefail
cd "$(dirname "$0")"
source tools.env
mkdir -p .tools/bin
curl -fsSL -o /tmp/swiftlint.zip "https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/portable_swiftlint.zip"
unzip -o -q /tmp/swiftlint.zip -d .tools/bin
curl -fsSL -o /tmp/xcodegen.zip "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip"
unzip -o -q /tmp/xcodegen.zip -d .tools
# A wrapper, not a symlink: XcodeGen finds its setting presets relative to its
# real executable path, and through a symlink it finds none (PRODUCT_NAME ends
# up empty and the build fails with 'module name "" is not a valid identifier').
rm -f .tools/bin/xcodegen
printf '#!/bin/sh\nexec "%s/.tools/xcodegen/bin/xcodegen" "$@"\n' "$PWD" > .tools/bin/xcodegen
chmod +x .tools/bin/xcodegen
.tools/bin/swiftlint version && .tools/bin/xcodegen --version
