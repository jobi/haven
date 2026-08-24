#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_DIR="$PROJECT_ROOT/build/device/Haven.app"
BIN_SRC="$PROJECT_ROOT/.build/arm64-apple-ios/debug/NativeHAApp"
BUNDLE_ID="org.bilien.haven"
DEVICE_ID="7DEE875C-F5B3-595E-84D3-4BAE345AB7BA"
SIGNING_IDENTITY="Apple Development: johan+apple@bilien.org (5RN24MB5AH)"
PROVISIONING_PROFILE="/Users/jobi/Library/Developer/Xcode/DerivedData/NativeHA-aiptjegnrxarumhcdbyjucdbbnno/Build/Products/Debug-iphoneos/Haven.app/embedded.mobileprovision"

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

# Copy Privacy manifest
if [ -f "Sources/NativeHAApp/PrivacyInfo.xcprivacy" ]; then
    cp "Sources/NativeHAApp/PrivacyInfo.xcprivacy" "$APP_DIR/"
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

cat << EOF > "$APP_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Haven</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
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

if [ -f "$PROVISIONING_PROFILE" ]; then
    echo "==> Embedding provisioning profile..."
    cp "$PROVISIONING_PROFILE" "$APP_DIR/embedded.mobileprovision"
    
    # Extract entitlements
    TMP_ENTITLEMENTS="$(mktemp /tmp/entitlements_XXXXXX.plist)"
    security cms -D -i "$PROVISIONING_PROFILE" > "$TMP_ENTITLEMENTS"
    /usr/libexec/PlistBuddy -x -c "Print :Entitlements" "$TMP_ENTITLEMENTS" > "$APP_DIR/Entitlements.plist" 2>/dev/null || true
    rm -f "$TMP_ENTITLEMENTS"
    
    echo "==> Signing app bundle with developer certificate..."
    if [ -f "$APP_DIR/Entitlements.plist" ]; then
        codesign --force --timestamp=none --sign "$SIGNING_IDENTITY" --entitlements "$APP_DIR/Entitlements.plist" "$APP_DIR"
        rm -f "$APP_DIR/Entitlements.plist"
    else
        codesign --force --timestamp=none --sign "$SIGNING_IDENTITY" "$APP_DIR"
    fi
else
    echo "==> Signing app bundle with ad-hoc signature..."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "==> Installing Haven on Johan's iPhone ($DEVICE_ID)..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_DIR"

echo "==> Launching Haven ($BUNDLE_ID)..."
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "==> Success! Haven with Multi-Server and Quick Actions is running on Johan's iPhone."
