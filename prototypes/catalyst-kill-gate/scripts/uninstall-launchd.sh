#!/bin/bash
# Removes the spike's launchd agent and stops the process. Run this when done —
# it is a throwaway spike and should not linger on your machine.
set -euo pipefail

LABEL="com.gatespike.agent"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null && echo "booted out" || echo "not loaded"
rm -f "$PLIST" && echo "removed $PLIST"
pkill -f "GateSpike.app/Contents/MacOS/GateSpike" 2>/dev/null && echo "killed process" || echo "no process"
rm -f /tmp/gatespike.stdout.log /tmp/gatespike.stderr.log
echo "done"
