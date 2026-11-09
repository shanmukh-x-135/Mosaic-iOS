#!/usr/bin/env bash
# Archives a signed Release build for TestFlight.
# Requires a paid Apple Developer team with the bundle ID
# com.shanmukhpgsspersonalteam.MosaiciOS registered in App Store Connect.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ARCHIVE_PATH="${ARCHIVE_PATH:-build/Mosaic.xcarchive}"
xcodebuild archive \
  -project Mosaic-iOS.xcodeproj \
  -scheme Mosaic-iOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  "$@"
cat <<MESSAGE

Archive written to: $ARCHIVE_PATH

Upload with Xcode Organizer (Window → Organizer → Archives → Distribute App →
App Store Connect → Upload), or export it first:
  xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \\
    -exportOptionsPlist ExportOptions.plist -exportPath build/export
MESSAGE
