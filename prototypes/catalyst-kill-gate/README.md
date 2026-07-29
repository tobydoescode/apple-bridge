# GateSpike — Catalyst kill-gate

Throwaway spike for [apple-bridge#15](https://github.com/tobydoescode/apple-bridge/issues/15).

**Verdict: the three fatal checks pass. Single-process Catalyst is viable and the
two-process split is not forced.** Checks 2, 3 and 5 — socket, live HomeKit,
launchd — all pass together in one process, which was the actual question. Check 4
passes. Check 1 passes with a caveat: headless at launch and steady state, but
activation still creates a window.

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
| 1 | Headless — no window, no dock icon | **PASS with caveat** — `activationPolicy=accessory`, no window at launch or steady state; **activation still creates one** |
| 2 | Binds socket, serves HTTP, sandboxed | **PASS** — `NWListener` on 127.0.0.1:23499 from inside the container |
| 3 | Live `HMHomeManager` | **PASS** — `authorized+determined`, home loaded in 0.5–1.4s |
| 4 | `NSStatusItem` via AppKit plugin bundle | **PASS** — status item created from the Catalyst process |
| 5 | Started and kept alive by launchd | **PASS** — `RunAtLoad`, and `runs=2` after a kill proves respawn |

Home read (bonus data for
[#18](https://github.com/tobydoescode/apple-bridge/issues/18)): **17 rooms, 226
accessories, 4 zones, 13 user-defined scenes**, structure only, no characteristic
reads.

## The five findings that cost time

**1. A Catalyst app cannot be kept windowless across activation.** Three things
were tried and the honest result is partial:

- `LSUIElement` **works** for the dock icon — `NSApplication.activationPolicy()`
  reports `.accessory`, no Dock presence, no app menu.
- With **no** `UIApplicationSceneManifest`, UIKit falls back to legacy
  single-window behaviour and shows a blank window immediately.
- With the manifest *present* and declaring *zero* configurations, plus no
  `configurationForConnecting` override, the app launches with **no window** —
  but **activating it (e.g. `open`) still produces one.** Catalyst grants a
  default scene on activation regardless.

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key><false/>
    <key>UISceneConfigurations</key><dict/>
</dict>
```

So: headless at launch and at steady state under launchd — which is the case that
matters for a daemon, since nothing activates it — but not *permanently*
windowless. A real app needs a workaround for the activation case. Untested
candidate: have the AppKit plugin observe `NSWindow` creation and close or order
it out, since the plugin is the only code that can see AppKit.

Note `appKitWindows` is 1 even when nothing is visible; that is Catalyst's
internal host window. Don't read it as failure.

**Also, an instructive self-inflicted wound:** an earlier version implemented
`configurationForConnecting` purely to *record* that UIKit had asked for a scene.
Returning a valid `UISceneConfiguration` **grants** the request — so the
instrumentation was itself creating the window it reported.

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

**5. `NSApplication.terminate` does not reliably quit a Catalyst process.** A
status-bar Quit wired to `#selector(NSApplication.terminate(_:))` took **two**
clicks: the first surfaced the host window instead of exiting. Routing the menu
action back into the Catalyst side and calling `exit(0)` exits cleanly on one
click. The plugin therefore takes a quit handler rather than talking to `NSApp`.

Separately: under a launchd job with unconditional `KeepAlive`, Quit is
unwinnable — the process exits, `open -W` returns, launchd respawns it, forever.
A real daemon's Quit must either stop the launchd job or the plist must make
`KeepAlive` conditional.

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
