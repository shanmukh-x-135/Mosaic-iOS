#!/usr/bin/env bash
# Runs the Mosaic iOS unit tests.
# Override the simulator with DESTINATION="platform=iOS Simulator,name=iPhone 17".
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
exec xcodebuild test \
  -project Mosaic-iOS.xcodeproj \
  -scheme Mosaic-iOS \
  -destination "$DESTINATION" \
  "$@"
