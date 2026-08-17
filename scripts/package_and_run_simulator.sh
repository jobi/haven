#!/bin/bash
set -e

APP_DIR="build/NativeHA.app"
BIN_SRC=".build/arm64-apple-ios-simulator/debug/NativeHAApp"
BUNDLE_ID="com.nativeha.client"

echo "==> Creating .app bundle structure..."
mkdir -p "$APP_DIR"
cp "$BIN_SRC" "$APP_DIR/NativeHA"

cat << 'EOF' > "$APP_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>NativeHA</string>
    <key>CFBundleIdentifier</key>
    <string>com.nativeha.client</string>
    <key>CFBundleName</key>
    <string>NativeHA</string>
    <key>CFBundleDisplayName</key>
    <string>NativeHA</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.nativeha.auth</string>
            <key>CFBundleURLSchemes</key>
            <array>
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
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
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

echo "==> Launching NativeHA ($BUNDLE_ID)..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "==> Success! NativeHA is running in the iPhone simulator."
