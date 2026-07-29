#!/bin/bash
# THE one command. Build, launch, poll, print the scorecard.
#
# Execs the inner binary directly rather than using `open`, for two reasons:
# it is exactly how launchd will start it in check 5, and this bundle reuses the
# App ID com.scenelab.poc — so `open` would resolve the bundle id via
# LaunchServices and might launch SceneLab.app instead.
#
# Reusing that App ID is deliberate: it is the only one on team FRB6K6JADV with
# the HomeKit capability enabled, and Xcode cannot add that capability itself
# (the portal marks HOMEKIT as not requestable). Side effect: the existing
# HomeKit TCC grant is inherited, so there is no first-run prompt — see the
# LIMITATION note in README.md.
set -euo pipefail

cd "$(dirname "$0")/.."
APP=".build/xcode/Build/Products/Debug-maccatalyst/GateSpike.app"
PORT=23499

./scripts/build.sh

echo
echo "--- stopping any previous instance ---"
pkill -f "GateSpike.app/Contents/MacOS/GateSpike" 2>/dev/null && echo "killed old instance" || echo "none running"
sleep 1

echo
echo "--- launching ---"
"$APP/Contents/MacOS/GateSpike" > /tmp/gatespike.direct.log 2>&1 &
echo "pid $!"

echo "waiting for 127.0.0.1:$PORT ..."
for i in $(seq 1 30); do
  if curl -s --max-time 1 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
    echo "up after ${i}s"
    break
  fi
  sleep 1
done

echo
curl -s --max-time 5 "http://127.0.0.1:$PORT/" > /tmp/gatespike-report.json || {
  echo "NO RESPONSE — check 2 failed, or the app never launched."
  echo "Try: log show --last 2m --predicate 'process == \"GateSpike\"' --info"
  exit 1
}

./scripts/scorecard.sh
