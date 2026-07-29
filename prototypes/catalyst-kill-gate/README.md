# GateSpike — Catalyst kill-gate

Throwaway spike for [apple-bridge#15](https://github.com/tobydoescode/apple-bridge/issues/15).

**Verdict: all five checks pass. Single-process Catalyst is viable. The two-process
split is not forced.**

The question: can a Mac Catalyst app run headless under launchd, bind a listening
socket, hold a live `HMHomeManager`, and show a status bar item — with no window
and no Xcode? If any of checks 2, 3 or 5 had failed, the architecture would have
been forced into a SwiftPM CLI daemon plus a separate Catalyst HomeKit helper
talking over IPC.

## Run it

```bash
./scripts/run.sh              # build, launch, print the scorecard
./scripts/install-launchd.sh  # check 5: run it under a launchd agent
./scripts/uninstall-launchd.sh
```

Everything reports over one endpoint — `curl http://127.0.0.1:23499/` returns the
full JSON state, and `./scripts/scorecard.sh` renders it as the five checks.

## Results

| # | Check | Result |
|---|---|---|
| 1 | Headless — no window, no dock icon | **PASS** — `activationPolicy=accessory`, no visible window |
| 2 | Binds socket, serves HTTP, sandboxed | **PASS** — `NWListener` on 127.0.0.1:23499 from inside the container |
| 3 | Live `HMHomeManager` | **PASS** — `authorized+determined`, home loaded in 0.5–1.4s |
| 4 | `NSStatusItem` via AppKit plugin bundle | **PASS** — status item created from the Catalyst process |
| 5 | Started and kept alive by launchd | **PASS** — `RunAtLoad`, and `runs=2` after a kill proves respawn |

Home read (bonus data for
[#18](https://github.com/tobydoescode/apple-bridge/issues/18)): **17 rooms, 226
accessories, 4 zones, 13 user-defined scenes**, structure only, no characteristic
reads.

## The four findings that cost time

**1. `LSUIElement` alone does not give you a windowless app.** It suppresses the
dock icon — `NSApplication.activationPolicy()` really does report `.accessory` for
a Catalyst bundle — but with **no** `UIApplicationSceneManifest`, UIKit falls back
to legacy single-window behaviour and puts a blank window on screen. The fix is a
manifest that is *present* and declares *zero* scene configurations:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key><false/>
    <key>UISceneConfigurations</key><dict/>
</dict>
```

AppKit still reports exactly one window and UIKit still calls
`configurationForConnecting`, but nothing is shown. Don't read either signal as
failure.

**2. launchd must not exec the inner binary.** Doing what the current
apple-bridge plist does — pointing `ProgramArguments` straight at the executable —
makes TCC **kill the process** on first HomeKit use:

> namespace TCC: This app has crashed because it attempted to access
> privacy-sensitive data without a usage description. The app's Info.plist must
> contain an `NSHomeKitUsageDescription` key…

The key *was* present in the built `Info.plist`. A direct exec bypasses
LaunchServices, so the process never acquires bundle identity and TCC judges it as
unbundled code. Route through `open` instead:

```xml
<key>ProgramArguments</key>
<array>
    <string>/usr/bin/open</string>
    <string>-W</string>
    <string>-n</string>
    <string>/path/to/App.app</string>
</array>
```

`-W` blocks until the app exits, which is what `KeepAlive` needs to see a death
and respawn.

**3. Xcode cannot grant itself the HomeKit capability.** `xcodebuild
-allowProvisioningUpdates` on a fresh bundle id (`com.scenelab.gatespike`) issued a
**wildcard** profile and then failed with *"Entitlement
com.apple.developer.homekit not found and could not be included in profile."*
Wildcard App IDs cannot carry HomeKit, and the portal marks the capability as not
requestable — so a new App ID needs the capability enabled by hand.

**Workaround used here:** this bundle reuses `com.scenelab.poc`, the only App ID
on team `FRB6K6JADV` that already has HomeKit enabled.

**4. Cross-platform target dependency works.** A macOS `.bundle` target
(`SDKROOT=macosx`, AppKit-linked) built as a dependency of a Catalyst app target,
copied into `Contents/PlugIns`, `dlopen`'d at runtime. The plugin reports
`LC_BUILD_VERSION platform 1` (macOS) inside a maccatalyst host, and loads fine.
The `@objc(GSStatusBarPluginProtocol)` name on the duplicated protocol is
load-bearing — without it Swift mangles the runtime name per module and every cast
fails.

## Limitations

- **First-run TCC consent is untested.** Reusing `com.scenelab.poc` inherited
  SceneLab's existing HomeKit grant, so this spike never saw a permission prompt.
  Whether a *headless* app with no window can get a prompt shown at all is open —
  and both research tickets independently flagged the same gap for EventKit.
- **Logout/login persistence unverified.** Respawn-after-kill is proven; surviving
  a full session cycle is not.
- **Swift 5 language mode**, not 6. Strict concurrency was not the question here.
- The spike is **read-only** against HomeKit. It creates, renames and deletes
  nothing.

## Layout

```
GateSpike.xcodeproj      Two targets: Catalyst app + macOS AppKit bundle.
GateSpike/               App: AppDelegate, HTTP probe, HomeKit probe, plugin loader.
StatusBarPlugin/         AppKit code — the only place AppKit is reachable.
GateSpike.entitlements   app-sandbox, developer.homekit, network.server/client.
scripts/                 build, run, scorecard, launchd install/uninstall.
```
