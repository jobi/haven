#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

OUT_DIR="$PROJECT_ROOT/screenshots"
mkdir -p "$OUT_DIR"

echo "==> 1. Setting clean Apple marketing status bar (9:41 AM, 100% battery, full wifi)..."
xcrun simctl status_bar booted override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularMode active \
    --cellularBars 4 \
    --wifiMode active \
    --wifiBars 3

sleep 1

echo "==> 2. Capturing Screenshot 1: Home Overview Dashboard..."
xcrun simctl terminate booted org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch booted org.bilien.haven -demo -view home
sleep 3
xcrun simctl io booted screenshot "$OUT_DIR/01_home_overview.png"

echo "==> 3. Capturing Screenshot 2: Security & Live Cameras..."
xcrun simctl terminate booted org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch booted org.bilien.haven -demo -view security
sleep 3
xcrun simctl io booted screenshot "$OUT_DIR/02_security_cameras.png"

echo "==> 4. Capturing Screenshot 3: Energy & Climate Gauges..."
xcrun simctl terminate booted org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch booted org.bilien.haven -demo -view energy
sleep 3
xcrun simctl io booted screenshot "$OUT_DIR/03_energy_climate.png"

echo "==> 5. Capturing Screenshot 4: Light Color & Brightness Control..."
xcrun simctl terminate booted org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch booted org.bilien.haven -demo -view home -more_info light.living_room_ceiling
sleep 3
xcrun simctl io booted screenshot "$OUT_DIR/04_light_color_picker.png"

echo "==> 6. Capturing Screenshot 5: 24h Interactive Sensor History Chart..."
xcrun simctl terminate booted org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch booted org.bilien.haven -demo -view home -more_info sensor.living_room_temperature
sleep 3
xcrun simctl io booted screenshot "$OUT_DIR/05_sensor_history.png"

echo "==> 7. Capturing Screenshot 6: Multi-Server Management & Settings..."
xcrun simctl terminate booted org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch booted org.bilien.haven -demo -view home -settings
sleep 3
xcrun simctl io booted screenshot "$OUT_DIR/06_multi_server_settings.png"

echo "==> Resetting to Home view..."
xcrun simctl terminate booted org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch booted org.bilien.haven -demo -view home

echo ""
echo "============================================================"
echo " ✅ All 6 App Store Screenshots Generated in: $OUT_DIR"
echo "============================================================"
ls -lh "$OUT_DIR"
