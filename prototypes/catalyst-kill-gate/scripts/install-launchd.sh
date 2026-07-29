#!/bin/bash
# CHECK 5. Installs the launchd agent pointing at the built app, then reports
# whether launchd actually kept a Catalyst app alive.
set -euo pipefail

cd "$(dirname "$0")/.."
APP_PATH="$(cd "$(dirname ".build/xcode/Build/Products/Debug-maccatalyst/GateSpike.app")" && pwd)/GateSpike.app"
LABEL="com.gatespike.agent"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

[ -d "$APP_PATH" ] || { echo "app not built — run ./scripts/build.sh first"; exit 1; }

mkdir -p "$HOME/Library/LaunchAgents"
sed "s|@APP_PATH@|$APP_PATH|g" scripts/com.gatespike.agent.plist.template > "$PLIST"
echo "wrote $PLIST -> $APP_PATH"

# Stop anything already running so the launchd-started instance owns the port.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -f "GateSpike.app/Contents/MacOS/GateSpike" 2>/dev/null || true
sleep 1
rm -f /tmp/gatespike.stdout.log /tmp/gatespike.stderr.log

launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "bootstrapped. waiting..."
sleep 5

echo
echo "--- launchctl print ---"
launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E "state|pid|last exit|program|runs" | head -10 || echo "not loaded"

echo
echo "--- stdout ---"
cat /tmp/gatespike.stdout.log 2>/dev/null || echo "(empty — the sandbox may have blocked the inherited fd, or the app never ran)"
echo "--- stderr ---"
cat /tmp/gatespike.stderr.log 2>/dev/null || echo "(empty)"

echo
if curl -s --max-time 3 "http://127.0.0.1:23499/" > /tmp/gatespike-report.json 2>/dev/null; then
  echo "responded over HTTP while launchd-managed:"
  ./scripts/scorecard.sh
else
  echo "NO HTTP RESPONSE under launchd — check 5 fails (or check 2 fails in this context)."
  echo "Diagnose: log show --last 3m --predicate 'process == \"GateSpike\"' --info | tail -40"
fi

echo
echo "Respawn test: kill it and see whether launchd brings it back."
echo "  pkill -f GateSpike.app/Contents/MacOS/GateSpike && sleep 8 && curl -s http://127.0.0.1:23499/ | head -5"
echo "Logout/login persistence must be checked by hand."
echo "Remove with: ./scripts/uninstall-launchd.sh"
