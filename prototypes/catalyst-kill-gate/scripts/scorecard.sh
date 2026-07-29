#!/bin/bash
# Prints the five kill-gate checks from the last report. Check 5 (launchd) is
# reported from the environment, since only launchd can set it.
set -euo pipefail

REPORT="${1:-/tmp/gatespike-report.json}"
[ -f "$REPORT" ] || { echo "no report at $REPORT — run ./scripts/run.sh first"; exit 1; }

python3 - "$REPORT" <<'PY'
import json, sys

r = json.load(open(sys.argv[1]))

def g(k, default=None):
    return r.get(k, default)

def verdict(ok):
    return "PASS" if ok is True else ("FAIL" if ok is False else "UNKNOWN")

policy = g("check1_activation_policy")

# Check 1 is "no window AND no dock icon". Scoring it on the dock icon alone
# scored a PASS while a blank window was visibly on screen — appKitWindows was 1
# in the very same report. Both halves must hold.
# MEASURED: with an empty UIApplicationSceneManifest, no window is visible on
# screen (human-confirmed) even though AppKit still reports exactly one window
# and UIKit still calls configurationForConnecting. That one window is Catalyst's
# internal host window and is never shown. More than one means a real window.
no_dock = g("check1_no_dock_icon")
windows = g("check1_appkit_window_count")
check1 = None if no_dock is None or windows is None else (
    no_dock is True and windows <= 1
)

rows = [
    ("1. Headless — no window, no dock icon",
     check1,
     f"activationPolicy={policy}  appKitWindows={g('check1_appkit_window_count')}  "
     f"connectedScenes={g('connected_scenes')}  sceneManifest={g('scene_manifest_present')}  "
     f"sceneRequested={g('check1_scene_requested', False)}"),

    ("2. Binds socket, serves HTTP, sandboxed",
     g("check2_socket_bound"),
     f"{g('check2_detail')}  (you are reading this over that socket)"),

    ("3. Live HMHomeManager",
     g("check3_homes_loaded"),
     f"auth={g('check3_authorization')}  home={g('check3_primary_home')}  "
     f"rooms={g('check3_room_count')}  accessories={g('check3_accessory_count')}  "
     f"zones={g('check3_zone_count')}  userScenes={g('check3_user_scene_count')}  "
     f"timeToHomes={g('check3_time_to_homes_seconds')}s"),

    ("4. NSStatusItem via AppKit plugin bundle",
     g("check4_status_item_shown"),
     f"{g('check4_detail')}"),

    ("5. Started and kept alive by launchd",
     g("launched_by_launchd"),
     "true only when launched by the launchd agent — run ./scripts/install-launchd.sh"),
]

print("=" * 78)
print("CATALYST KILL-GATE SCORECARD")
print("=" * 78)
for name, ok, detail in rows:
    print(f"{verdict(ok):>7}  {name}")
    print(f"         {detail}")
print("=" * 78)

fatal = ["2. Binds socket, serves HTTP, sandboxed", "3. Live HMHomeManager",
         "5. Started and kept alive by launchd"]
failed = [n for n, ok, _ in rows if ok is not True]
fatal_failed = [n for n in failed if n in fatal]

print(f"pid={g('pid')} uptime={g('uptime_seconds')}s sandboxHome={g('home_dir')}")
print()
if not failed:
    print("VERDICT: single-process Catalyst is viable. All five pass.")
elif fatal_failed:
    print("VERDICT: single-process is DEAD — the split is forced.")
    print("Fatal failures:", "; ".join(fatal_failed))
else:
    print("VERDICT: survivable. Only non-fatal checks failed:", "; ".join(failed))
    print("Checks 1 and 4 can be dropped or worked around; 2, 3 and 5 cannot.")

unreachable = g("check3_unreachable_accessories") or []
if unreachable:
    print(f"\nunreachable accessories ({len(unreachable)}): {', '.join(unreachable)}")
print(f"\nfull report: {sys.argv[1]}")
PY
