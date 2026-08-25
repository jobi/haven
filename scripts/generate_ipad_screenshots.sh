#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

IPAD_DEVICE_ID="59CAAC3A-F047-4611-B8B6-72ED55239DAE"
OUT_DIR="$PROJECT_ROOT/screenshots/ipad_13"
mkdir -p "$OUT_DIR"

echo "==> 1. Booting iPad Pro 13-inch Simulator..."
xcrun simctl boot "$IPAD_DEVICE_ID" >/dev/null 2>&1 || true

echo "==> 2. Installing Haven..."
xcrun simctl install "$IPAD_DEVICE_ID" build/Haven.app

echo "==> 3. Setting clean Apple marketing status bar (9:41 AM, 100% battery, full wifi)..."
xcrun simctl status_bar "$IPAD_DEVICE_ID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiMode active \
    --wifiBars 3

sleep 1

echo "==> 4. Capturing Screenshot 1: Home Overview Dashboard..."
xcrun simctl terminate "$IPAD_DEVICE_ID" org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch "$IPAD_DEVICE_ID" org.bilien.haven -demo -view home
sleep 3
xcrun simctl io "$IPAD_DEVICE_ID" screenshot "$OUT_DIR/01_ipad_home_dashboard.png"

echo "==> 5. Capturing Screenshot 2: Security & Live Cameras..."
xcrun simctl terminate "$IPAD_DEVICE_ID" org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch "$IPAD_DEVICE_ID" org.bilien.haven -demo -view security
sleep 3
xcrun simctl io "$IPAD_DEVICE_ID" screenshot "$OUT_DIR/02_ipad_security_cameras.png"

echo "==> 6. Capturing Screenshot 3: Energy & Climate Gauges..."
xcrun simctl terminate "$IPAD_DEVICE_ID" org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch "$IPAD_DEVICE_ID" org.bilien.haven -demo -view energy
sleep 3
xcrun simctl io "$IPAD_DEVICE_ID" screenshot "$OUT_DIR/03_ipad_energy_climate.png"

echo "==> 7. Capturing Screenshot 4: Light Color & Brightness Control..."
xcrun simctl terminate "$IPAD_DEVICE_ID" org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch "$IPAD_DEVICE_ID" org.bilien.haven -demo -view home -more_info light.living_room_ceiling
sleep 3
xcrun simctl io "$IPAD_DEVICE_ID" screenshot "$OUT_DIR/04_ipad_light_controls.png"

echo "==> 8. Capturing Screenshot 5: 24h Interactive Sensor History Chart..."
xcrun simctl terminate "$IPAD_DEVICE_ID" org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch "$IPAD_DEVICE_ID" org.bilien.haven -demo -view home -more_info sensor.living_room_temperature
sleep 3
xcrun simctl io "$IPAD_DEVICE_ID" screenshot "$OUT_DIR/05_ipad_sensor_history.png"

echo "==> 9. Capturing Screenshot 6: Multi-Server Management & Settings..."
xcrun simctl terminate "$IPAD_DEVICE_ID" org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch "$IPAD_DEVICE_ID" org.bilien.haven -demo -view home -settings
sleep 3
xcrun simctl io "$IPAD_DEVICE_ID" screenshot "$OUT_DIR/06_ipad_multi_server_settings.png"

echo "==> Resetting to Home view..."
xcrun simctl terminate "$IPAD_DEVICE_ID" org.bilien.haven >/dev/null 2>&1 || true
xcrun simctl launch "$IPAD_DEVICE_ID" org.bilien.haven -demo -view home
sleep 2

# Formatting check and verification
echo ""
echo "============================================================"
echo " ✅ All 6 iPad Pro 13\" App Store Screenshots Generated"
echo " Location: $OUT_DIR"
echo "============================================================"
for img in "$OUT_DIR"/*.png; do
    w=$(sips -g pixelWidth "$img" | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$img" | awk '/pixelHeight/{print $2}')
    echo "  • $(basename "$img"): ${w} × ${h} px"
done
