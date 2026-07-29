#!/bin/bash
# Signed Catalyst build. Unlike the SceneLab PoC's build script this one does NOT
# disable signing — the whole point is exercising the HomeKit entitlement and the
# sandbox, so an unsigned build proves nothing.
#
# -allowProvisioningUpdates lets Xcode register the new App ID
# (com.scenelab.gatespike) and mint a development profile with the HomeKit
# capability, without opening the GUI.
set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild \
  -project GateSpike.xcodeproj \
  -scheme GateSpike \
  -configuration Debug \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath .build/xcode \
  -allowProvisioningUpdates \
  build 2>&1 | tee /tmp/gatespike-build.log \
  | grep -E "error:|warning:|BUILD|Signing|CodeSign|ProcessInfoPlistFile|CopyPlugIn" || true

if grep -q "^\*\* BUILD SUCCEEDED" /tmp/gatespike-build.log; then
  echo "BUILD SUCCEEDED"
  APP=".build/xcode/Build/Products/Debug-maccatalyst/GateSpike.app"
  echo "app: $APP"
  echo
  echo "--- what actually got built ---"
  echo "plugin bundle:"
  ls -d "$APP/Contents/PlugIns/"*.bundle 2>/dev/null || echo "  MISSING — copy phase did not run"
  echo "plugin platform (expect LC_BUILD_VERSION platform 1 = macOS):"
  otool -l "$APP/Contents/PlugIns/StatusBarPlugin.bundle/Contents/MacOS/StatusBarPlugin" 2>/dev/null \
    | grep -A3 LC_BUILD_VERSION | grep -E "platform|minos" | head -4 || echo "  n/a"
  echo "entitlements as signed:"
  codesign -d --entitlements - --xml "$APP" 2>/dev/null \
    | plutil -convert xml1 -o - - 2>/dev/null | grep -E "<key>|<true|<false" || echo "  none"
else
  echo "BUILD FAILED — see /tmp/gatespike-build.log"
  tail -40 /tmp/gatespike-build.log
  exit 1
fi
