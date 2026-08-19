#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_DIR="$PROJECT_ROOT/build/device/Haven.app"
BIN_SRC="$PROJECT_ROOT/.build/arm64-apple-ios/debug/NativeHAApp"
BUNDLE_ID="com.nativeha.haven"
DEVICE_ID="7DEE875C-F5B3-595E-84D3-4BAE345AB7BA"

echo "==> Building Haven for iOS Device (arm64)..."
swift build \
    --triple arm64-apple-ios17.0 \
    --sdk $(xcrun --sdk iphoneos --show-sdk-path) \
    --product NativeHAApp

echo "==> Creating .app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp "$BIN_SRC" "$APP_DIR/Haven"

if [ -d "$PROJECT_ROOT/.build/arm64-apple-ios/debug/NativeHA_NativeHACore.bundle" ]; then
    cp -R "$PROJECT_ROOT/.build/arm64-apple-ios/debug/NativeHA_NativeHACore.bundle" "$APP_DIR/"
fi

# Compile Asset Catalog for AppIcon
TMP_PLIST="$(mktemp /tmp/assets_info_XXXXXX.plist)"
xcrun actool Sources/NativeHAApp/Assets.xcassets \
    --compile "$APP_DIR" \
    --platform iphoneos \
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
    <string>com.nativeha.haven</string>
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

echo "==> Signing app bundle with ad-hoc signature..."
codesign --force --deep --sign - "$APP_DIR"
