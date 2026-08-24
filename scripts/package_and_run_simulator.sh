#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_DIR="build/Haven.app"
BIN_SRC=".build/arm64-apple-ios-simulator/debug/NativeHAApp"
BUNDLE_ID="org.bilien.haven"

echo "==> Creating .app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp "$BIN_SRC" "$APP_DIR/Haven"

if [ -d ".build/arm64-apple-ios-simulator/debug/NativeHA_NativeHACore.bundle" ]; then
    cp -R ".build/arm64-apple-ios-simulator/debug/NativeHA_NativeHACore.bundle" "$APP_DIR/"
fi

# Compile Asset Catalog for AppIcon
TMP_PLIST="$(mktemp /tmp/assets_info_XXXXXX.plist)"
xcrun actool Sources/NativeHAApp/Assets.xcassets \
    --compile "$APP_DIR" \
    --platform iphonesimulator \
    --minimum-deployment-target 17.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$TMP_PLIST" > /dev/null 2>&1 || true
rm -f "$TMP_PLIST"

cat << 'EOF' > "$APP_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Haven</string>
    <key>CFBundleIdentifier</key>
    <string>org.bilien.haven</string>
    <key>CFBundleName</key>
    <string>Haven</string>
    <key>CFBundleDisplayName</key>
    <string>Haven</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIcons</key>
    <dict>
        <key>CFBundlePrimaryIcon</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>AppIcon60x60</string>
            </array>
            <key>CFBundleIconName</key>
            <string>AppIcon</string>
        </dict>
    </dict>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.haven.auth</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>haven</string>
                <string>nativeha</string>
                <string>homeassistant</string>
            </array>
        </dict>
    </array>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <key>UILaunchScreen</key>
    <dict/>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>
EOF

echo "==> Signing app bundle..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Booting iPhone 17 Pro simulator if not already booted..."
DEVICE_ID=$(xcrun simctl list devices | grep -E "iPhone 17 Pro \(" | head -n 1 | awk -F '[()]' '{print $2}')

if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(xcrun simctl list devices | grep -E "iPhone" | head -n 1 | awk -F '[()]' '{print $2}')
fi

echo "Using Simulator Device ID: $DEVICE_ID"

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true

echo "==> Opening Simulator application..."
open -a Simulator

echo "==> Installing app on simulator..."
xcrun simctl install "$DEVICE_ID" "$APP_DIR"

echo "==> Launching Haven ($BUNDLE_ID)..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "==> Success! Haven is running in the iPhone simulator."
