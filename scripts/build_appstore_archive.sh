#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

ARCHIVE_PATH="$PROJECT_ROOT/build/Haven.xcarchive"
PROJECT_PATH="$PROJECT_ROOT/NativeHA.xcodeproj"

echo "==> 1. Regenerating NativeHA.xcodeproj with org.bilien.haven..."
python3 scripts/generate_xcodeproj.py

echo "==> 2. Cleaning and creating App Store Release Archive..."
mkdir -p "$PROJECT_ROOT/build"
rm -rf "$ARCHIVE_PATH"

xcodebuild -project "$PROJECT_PATH" \
    -scheme Haven \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    archive

echo ""
echo "============================================================"
echo " ✅ Archive Created Successfully at: build/Haven.xcarchive"
echo "============================================================"
echo ""
echo "To distribute to App Store Connect:"
echo " 1. Open the archive in Xcode Organizer:"
echo "    open build/Haven.xcarchive"
echo " 2. In Xcode Organizer, select 'Haven' and click 'Distribute App'."
echo " 3. Select 'App Store Connect' -> 'Upload' -> follow prompts."
echo "============================================================"

# Open in Organizer if running in interactive desktop session
if [ "$1" == "--open" ]; then
    open "$ARCHIVE_PATH"
fi
