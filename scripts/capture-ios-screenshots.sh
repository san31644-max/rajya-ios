#!/bin/bash
set -euo pipefail
DEVICE_KIND="${1:-iphone}"
export DEVICE_KIND
mkdir -p build/screenshots build/screenshot-results
SIMULATOR_ID=$(xcrun simctl list devices available --json | python3 -c '
import json,os,sys
kind=os.environ["DEVICE_KIND"]
preferred=["iPhone 16 Pro", "iPhone 17 Pro", "iPhone 15 Pro"] if kind=="iphone" else ["iPad Pro 13-inch (M4)", "iPad Pro 13-inch (M5)", "iPad Pro (12.9-inch) (6th generation)"]
devices=[d for runtime,rows in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in rows if d.get("isAvailable")]
for name in preferred:
    match=next((d for d in devices if d["name"]==name),None)
    if match:
        print(match["udid"]);break
else:
    sys.exit("No supported "+kind+" simulator found: "+str([d["name"] for d in devices]))
')
xcrun simctl boot "$SIMULATOR_ID" || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b
xcrun simctl ui "$SIMULATOR_ID" appearance light
xcrun simctl status_bar "$SIMULATOR_ID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
set +e
xcodebuild test -project ios/Rajya.xcodeproj -scheme RajyaScreenshots \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath "build/screenshot-results/$DEVICE_KIND.xcresult" \
  CODE_SIGNING_ALLOWED=NO > "build/screenshot-results/$DEVICE_KIND.log" 2>&1
TEST_STATUS=$?
set -e
tail -n 70 "build/screenshot-results/$DEVICE_KIND.log"
if [ -d "build/screenshot-results/$DEVICE_KIND.xcresult" ]; then
  xcrun xcresulttool export attachments --path "build/screenshot-results/$DEVICE_KIND.xcresult" --output-path "build/screenshot-results/$DEVICE_KIND-attachments"
  python3 scripts/export-ios-screenshots.py "$DEVICE_KIND"
fi
xcrun simctl status_bar "$SIMULATOR_ID" clear || true
xcrun simctl shutdown "$SIMULATOR_ID" || true
exit "$TEST_STATUS"
