# Can a Developer ID profile carry the HomeKit entitlement?

Research for [#16](https://github.com/tobydoescode/apple-bridge/issues/16), under map [#13](https://github.com/tobydoescode/apple-bridge/issues/13).

Date: 2026-07-29. Local toolchain: Xcode 26.4 (17E192), `MacOSX26.4.sdk`. Apple team `FRB6K6JADV` (Apple Developer Program).

---

## Verdict

**No.** A Mac Catalyst app signed for Developer ID distribution **cannot** carry `com.apple.developer.homekit`.

Confidence: **high**. Four independent primary sources agree, one of which is a machine-readable
mirror of Apple's own provisioning portal shipped inside Xcode. Two of the four state the
restriction directly rather than by inference.

The consequence is blunt: **the map's standing constraint "Distribution: Developer ID, notarised,
direct download" is not achievable for a HomeKit app.** That decision needs revisiting — see
[Fallbacks](#6-fallbacks-ranked), where the ranking is unusually favourable because this project
targets a single Mac the maintainer owns.

There is also **no way to apply for an exception.** HomeKit is not a "managed" capability with an
approval path; Apple's capability record sets both `canRequestFromPortal: false` and
`distributionApprovalRequired: false` (see [1.3](#13-xcodes-own-copy-of-the-portal-capability-database)).
There is no form to file.

### Answers at a glance

| # | Question | Answer | Certainty |
|---|---|---|---|
| 1 | Developer ID profile can carry `com.apple.developer.homekit`? | **No.** Available for Development, Ad Hoc and App Store only | **Documented** |
| 2 | Embedded profile required at runtime? | **Yes** — and for Catalyst it is required *regardless* of HomeKit | **Documented** |
| 2 | Developer ID profile validity period | **18 years** from creation (profiles issued after 2017-02-22) | **Documented** |
| 3 | Behaviour when embedded profile expires | Profile is checked **at every launch**; on expiry **"the app will no longer launch"** | **Documented, but contradicted by Apple DTS in 2020 and never resolved** |
| 4 | Notarisation imposes extra rules on restricted entitlements? | **No.** The notary checks signature/timestamp/hardened-runtime/`get-task-allow`, not profile authorisation | **Documented by absence** |
| 4 | Catalyst-specific notarisation rules? | **None.** "Mac Catalyst" does not appear in the notarisation docs | **Documented by absence** |
| 5 | `NSHomeKitUsageDescription` / App Sandbox interaction? | **None documented.** No sandbox entitlement exists for HomeKit; the purpose string is a crash-avoidance requirement only | **Documented by absence** |
| 6 | Viable paths | Mac App Store, TestFlight (90-day churn), or local development signing (annual churn) | **Documented** |

### Methodology warning — read this before trusting any repeat of this research

Apple's `developer.apple.com/documentation/*` and `help/account/*` pages are JavaScript-rendered.
Naive fetching returns an empty shell, and **an LLM-summarising fetch of the macOS capability table
fabricated a checkmark for HomeKit under Developer ID — the exact opposite of the truth.**

Every capability-table claim below was extracted from **raw HTML DOM** (`curl` + explicit
`<td>`/`<figure class="icon-checksolid">` parsing) and independently reproduced by a second agent
using a real browser. Do not re-derive these facts with a summarising fetch. For Apple doc pages,
use the JSON backing store instead: `https://developer.apple.com/tutorials/data/documentation/<path>.json`.

---

## 1. The core question: HomeKit + Developer ID

### 1.1 Apple's macOS capability table — the authority DTS itself points to

[Supported capabilities (macOS)](https://developer.apple.com/help/account/reference/supported-capabilities-macos/)
opens with:

> The capabilities available to a macOS provisioning profile depend on your program membership and signing certificate.

Its three columns are defined on the page as:

> **ADP:** Apple Developer Program membership. Members of this paid program can distribute apps on the App Store.
> **Developer ID:** macOS apps signed with a Developer ID certificate.
> **Apple Developer:** Apple Account holders who have agreed to the Apple Developer Agreement to access certain resources on the Apple Developer website. No cost is associated with this agreement and developers can't distribute apps.

Extracted rows (raw DOM; `YES` = `icon-checksolid`, `—` = empty cell):

| Capability | ADP | Developer ID | Apple Developer |
|---|---|---|---|
| App Sandbox | YES | YES | YES |
| Hardened runtime | YES | YES | YES |
| App groups | YES | YES | YES |
| iCloud: CloudKit | YES | YES | — |
| Push notifications | YES | YES | — |
| Network extensions | YES | YES | — |
| Matter Allow Setup Payload | YES | YES | — |
| **HomeKit** | **YES** | **—** | **—** |
| Game Center | YES | — | — |
| Sign in with Apple | YES | — | — |
| Shared with You | YES | — | — |
| In-App Purchase | YES | — | — |
| WeatherKit | YES | — | — |

Two things make this cell load-bearing rather than a documentation gap:

1. **The Developer ID column is populated for most rows.** Blank is a deliberate signal, not missing data.
2. **Apple DTS designates this exact page as the answer to exactly this question.** In
   [thread 761458](https://developer.apple.com/forums/thread/761458) (Aug 2024) a DTS engineer wrote:

   > Based on the info later in your post, it sounds like your app is using a restricted entitlement, that is, one that must be authorised by a profile. […] As to what you can do about this, the first thing I'd check is that your restricted entitlements are compatible with Developer ID distribution. There's a [table in Developer Account Help](https://developer.apple.com/help/account/reference/supported-capabilities-macos) that lists most of them. If you're using one that's not listed there, use the technique from [Finding a Capability's Distribution Restrictions](https://developer.apple.com/forums/thread/721563).

[TN3125](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)
says the same thing in Apple's own voice:

> macOS supports provisioning profiles for both App Store and Developer ID distribution. Some entitlements are not supported by Developer ID profiles. For the details, see Supported capabilities (macOS) in Developer Account Help.

Contrast [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/),
where HomeKit is ✓ for ADP, ADEP **and** free Apple Developer accounts. The restriction is macOS-specific.

### 1.2 The entitlement's own documented platform availability excludes macOS and Catalyst

[HomeKit Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.homekit)
— platform availability read from Apple's JSON backing store:

```
iOS 8.0+, iPadOS 8.0+, tvOS 10.0+, visionOS 1.0+, watchOS 2.0+
```

**No macOS. No Mac Catalyst.** Whereas the [HomeKit *framework*](https://developer.apple.com/documentation/homekit)
does list Mac Catalyst 14.0+, and the local SDK confirms it:

```
/Applications/Xcode.app/.../MacOSX26.4.sdk/System/iOSSupport/System/Library/Frameworks/HomeKit.framework/Headers/HMHomeManager.h

API_AVAILABLE(ios(8.0), watchos(2.0), tvos(10.0), macCatalyst(14.0))
API_UNAVAILABLE(macos)
@interface HMHomeManager : NSObject
```

Same split for `NSHomeKitUsageDescription`
([docs](https://developer.apple.com/documentation/bundleresources/information-property-list/nshomekitusagedescription)):
iOS, iPadOS, visionOS, watchOS — no macOS, no Mac Catalyst.

**The framework is available to Catalyst but the entitlement is not documented for it.** That split is
the documentary fingerprint of the restriction: the API exists, the authorisation to use it outside
the App Store does not.

[Configuring HomeKit access](https://developer.apple.com/documentation/xcode/configuring-homekit-access) states flatly:

> The capability isn't available for macOS.

That sentence is about *native* macOS targets, not Catalyst — Apple DTS clarified the nuance in
[thread 822517](https://developer.apple.com/forums/thread/822517), where Quinn "The Eskimo!" wrote:

> HomeKit is an outlier in that it's supported on the Mac but only for Mac Catalyst apps.

and a second DTS engineer explained why native macOS is excluded:

> The main technical issue is that part of HomeKit (specifically, camera APIs like HMCameraView) are built on UIView, which prevents the framework from being 'directly' exported as a macOS framework.

So HomeKit-on-Catalyst is real and supported (the repo's own PoC proves it runs). The blocker is
purely the **distribution channel**.

### 1.3 Xcode's own copy of the portal capability database

This is the strongest single artifact, because it is Apple's provisioning-portal data in
machine-readable form, shipped inside the toolchain — no summarisation, no interpretation.

```
/Applications/Xcode.app/Contents/SharedFrameworks/DVTPortal.framework/Versions/A/Resources/
    DVTPortalCachedPortalCapabilities.json      # 427,014 bytes, dated 2026-03-11, 196 capabilities
```

The `HOMEKIT` record, verbatim (abridged):

```json
{
  "id": "HOMEKIT",
  "attributes": {
    "name": "HomeKit",
    "canRequestFromPortal": false,
    "distributionApprovalRequired": false,
    "developmentOnly": false,
    "distributionTypes": [
      { "name": "AD_HOC",      "displayValue": "Ad hoc" },
      { "name": "DEVELOPMENT", "displayValue": "Development" },
      { "name": "STORE",       "displayValue": "App Store Connect" }
    ],
    "entitlements": [
      { "name": "HomeKit", "profileKey": "com.apple.developer.homekit",
        "isRequiredInPlist": true, "valueType": "BOOLEAN" }
    ],
    "supportedSDKs": [ {"name":"IOS"}, {"name":"TV_OS"}, {"name":"VISION_OS"}, {"name":"WATCH_OS"} ],
    "validTeamTypes": [ "APPLE_DEVELOPER_ENTERPRISE_PROGRAM", "APPLE_DEVELOPER_PROGRAM",
                        "UNIVERSITY_PROGRAM", "XCODE_FREE_PROGRAM" ]
  }
}
```

**`DEVELOPER_ID` is absent from `distributionTypes`.**

The absence is meaningful, not an artifact of the schema. Across the 196 capabilities in the file:

```
DEVELOPMENT: 195    AD_HOC: 178    STORE: 176    DEVELOPER_ID: 71
```

71 capabilities do carry `DEVELOPER_ID` — including `ICLOUD`, `PUSH_NOTIFICATIONS`,
`NETWORK_EXTENSIONS`, `SYSTEM_EXTENSION_INSTALL`, `MAPS`, `MATTER_ALLOW_SETUP_PAYLOAD`, and
notably `ENABLED_FOR_MAC` (the Catalyst "Mac" checkbox itself). HomeKit is not one of them.

Also note `supportedSDKs` omits `MAC_OS` for HomeKit while `GAME_CENTER` — the row above it in the
help table — does include `MAC_OS`. And `canRequestFromPortal: false` +
`distributionApprovalRequired: false` together mean **this is not a capability you can apply for.**
There is no approval path to unlock.

#### The dataset validated against three cases Apple has already confirmed

`distributionTypes` predicts a specific Xcode export error. Three capabilities with the same shape
as HomeKit (`AD_HOC, DEVELOPMENT, STORE`, no `DEVELOPER_ID`) have publicly documented failures:

| Capability | `distributionTypes` | Observed outcome |
|---|---|---|
| `SHARED_WITH_YOU` | AD_HOC, DEVELOPMENT, STORE | Export error: *"The Shared with You capability is not available for Mac Catalyst Developer ID provisioning profiles. Disable this feature and try again."* ([thread 713677](https://developer.apple.com/forums/thread/713677), Sep 2022) |
| `APPLE_ID_AUTH` (Sign in with Apple) | AD_HOC, DEVELOPMENT, STORE | Same class; in the same thread a developer reports *"Apple later confirmed that indeed Sign in with Apple is not supported outside the Mac App Store, and the provisioning portal just strips that entitlement out for non-MAS provisioning profiles."* |
| `USER_ASSIGNED_DEVICE_NAME` | AD_HOC, DEVELOPMENT, STORE | Blocked on Catalyst ([thread 718657](https://developer.apple.com/forums/thread/718657)) |

And for HomeKit itself, the predicted error has been observed in the wild
([thread 651207](https://developer.apple.com/forums/thread/651207), aaronpearce, Jun 2020, Big Sur):

> HomeKit capabilities are not available for Mac Catalyst Developer ID provisioning profiles. Disable these features and try again.

The accepted answer in that thread was to abandon Developer ID:

> For the other HK developers out there, you will need to use the "add a UUID to your developer profile" method and export a development build.

Filed as FB7779724. **Six years later the capability record still lacks `DEVELOPER_ID`** — this is
settled behaviour, not a transient bug.

I checked whether that error string ships in Xcode locally (`grep -rl "capabilities are not
available for" over SharedFrameworks, Frameworks, PlugIns`) — **not present**, so the message is
generated server-side by the developer portal / provisioning service. The restriction is enforced at
**profile issuance**, before you ever reach a compiler or the notary.

### 1.4 Why you cannot route around it

`com.apple.developer.homekit` is a **restricted** entitlement. TN3125 defines the closed set of
*unrestricted* ones:

> A macOS app can claim certain entitlements without them being authorized by a provisioning profile. These *unrestricted entitlements* include:
> - `com.apple.security.get-task-allow`
> - `com.apple.security.application-groups`
> - Those used to enable and configure the App Sandbox
> - Those used to configure the Hardened Runtime
>
> In contrast, *restricted entitlements* must be authorized by a provisioning profile. This is an important security feature on macOS.

> Every entitlement claimed by the app must be in the profile's allowlist but the reverse isn't true. It's fine for the allowlist to include entitlements that the app doesn't claim.

HomeKit is not in the unrestricted list, so it must be allowlisted by a profile. Quinn confirms
directly in [thread 699085](https://developer.apple.com/forums/thread/699085) (Jan 2022):

> HomeKit requires the `com.apple.developer.homekit` entitlement, which must be allowlisted by a provisioning profile. You won't be able to do that on the Mac without a paid developer account.

Closing off each workaround:

- **Self-sign / ad-hoc sign the entitlement in.** Dead. A restricted entitlement claimed without
  profile authorisation fails code-signature validation at launch. Quinn, same thread:
  *"Apple silicon Macs require that all code be signed in some way. You can use ad hoc signing
  (Sign to Run Locally in Xcode) to satisfy this requirement"* — but *"Ad hoc signed code has all
  sorts of limitations"*, and decisively: *"Mac Catalyst apps always use the data protection
  keychain, and you can't do that without a provisioning profile."*
- **Split the HomeKit work into a helper process inside a Developer ID app.** Dead. The helper is the
  process claiming the entitlement, so it needs its own profile authorising HomeKit — and there is no
  Developer-ID-compatible profile that can. TN3125 confirms each executable needs its own embedded
  profile (`App.app/Contents/embedded.provisionprofile` *and*
  `.../PlugIns/X.appex/Contents/embedded.provisionprofile`). Mixing a development-signed helper into a
  Developer ID bundle also breaks notarisation, which rejects `get-task-allow`.
- **Ship Developer ID and hope.** Dead. Even if you force-sign and the notary accepts (it likely
  would — see [§4](#4-notarisation)), the app either fails to launch or HomeKit yields nothing.
- **Apply for an exception.** Dead. `canRequestFromPortal: false`.
- **`MATTER_ALLOW_SETUP_PAYLOAD`** *does* carry `DEVELOPER_ID`, which is a tempting near-miss — but it
  authorises passing a Matter setup payload during accessory pairing, not reading or mutating the
  HomeKit home database. Accessory pairing is explicitly out of scope for this map anyway.

### 1.5 Note: Catalyst itself is fine under Developer ID

Worth stating so the blame lands correctly. Quinn, [thread 699085](https://developer.apple.com/forums/thread/699085):

> Are Mac Catalyst apps subject to the same code signing requirements and associated distribution restrictions as iOS/iPad apps? No. In general, Mac Catalyst apps are Mac apps and follow the Mac code signing rules. For example, it's perfectly valid to distribute a Mac Catalyst app outside of the Mac App Store (MAS) using Developer ID.

`ENABLED_FOR_MAC` carries `DEVELOPER_ID` in the capability database, and
[Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
documents both *Direct Distribution* and *Developer ID* methods with Catalyst archive instructions.

**Catalyst is not the problem. HomeKit is.** Every other surface this project wants — HTTP server,
EventKit, MCP, web UI — is Developer-ID-distributable without difficulty.

#### Which capability table governs a Catalyst app? (the one inferred link)

A Catalyst app's Mac-side identity is a **macOS** App ID (derived from the iPad App ID by enabling
the "Mac" capability), and its profile is a macOS profile type. So the **macOS** table governs, not
the iOS one. Apple never states this table-selection rule in a single sentence — it is inference,
supported by:

- TN3125: *"On macOS the standard App ID entitlement is `com.apple.application-identifier`. A Mac Catalyst app uses both `com.apple.application-identifier` and `application-identifier`."*
- [Create a Mac version of an iPad app](https://developer.apple.com/help/account/capabilities/create-a-mac-version-of-an-ipad-app/): *"To build your app, create a Mac Catalyst Provisioning Profile and select your App ID."*
- The observed error message names *"Mac Catalyst Developer ID provisioning profiles"* explicitly.

This is the weakest joint in the argument, and it does not matter: §1.3's capability record is
platform-agnostic and still lacks `DEVELOPER_ID`, and §1.2's observed error is Catalyst-specific.
Both routes reach the same verdict.

---

## 2. Embedded provisioning profile: requirement and validity

### 2.1 When a profile is required

[Creating distribution-signed code for macOS](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac):

> For security reasons, a provisioning profile needs to authorize most entitlement claims.

> If your program claims a restricted entitlement, include a distribution provisioning profile to authorize that claim as follows: 1. Create the profile on the developer website… Make sure to choose a profile type that matches your distribution channel (Mac App Store or Developer ID). 2. Copy that profile into your program's bundle.

TN3125:

> A Mac app that uses no restricted entitlements doesn't need a provisioning profile. This is true even if the app is distributed on the App Store. The only exception to this rule is TestFlight, which always requires a profile.

Location: `MyApp.app/Contents/embedded.provisionprofile`. Apple does **not** publish an enumerated
list of restricted entitlements — the rule is the negative of the four unrestricted categories.

**For this project the answer is unconditional: yes.** A Mac Catalyst app *always* needs an embedded
profile, independent of HomeKit, because *"Mac Catalyst apps always use the data protection keychain,
and you can't do that without a provisioning profile"* (Quinn, thread 699085).

### 2.2 Validity: 18 years — documented, and the folklore figure is correct

[Developer ID support page](https://developer.apple.com/support/developer-id/):

> Developer ID certificates are valid for 5 years from the date of creation and Developer ID provisioning profiles generated prior to February 22, 2017\*, are valid until your Developer ID certificate expires.

> \* To simplify the management of your Developer ID apps and to ensure an uninterrupted experience for your users, Developer ID provisioning profiles generated after February 22, 2017, are valid for 18 years from the creation date, regardless of the expiration date of your Developer ID certificate.

Restated in [Developer Account Help](https://developer.apple.com/help/account/certificates/create-developer-id-certificates):

> Developer ID provisioning profiles generated after February 22, 2017, are valid for 18 years from the creation date, regardless of the expiration date of your Developer ID certificate.

And announced by Apple Staff in Feb 2017 ([thread 73021](https://developer.apple.com/forums/thread/73021)):

> To make managing your Developer ID app easier, newly generated Developer ID Provisioning Profiles are now valid for 18 years from the date of issuance. Apps utilizing a Developer ID provisioning profile can be installed as long as they are signed with a valid Developer ID Application signing certificate and will run uninterrupted as long as the Developer ID Provisioning Profile remains valid.

(Apple's own pages disagree on the cutover date: the announcement says February 21, the support
pages say February 22. Immaterial in 2026.)

TN3125 gives the mechanism without a number:

> Every profile has an `ExpirationDate` property which limits how long the profile remains valid… This validity period varies by profile type, but it's typically not more than a year. The exception here is Developer ID profiles, which have an expiration date far in the future.

Corroborated empirically by Quinn ([thread 702420](https://developer.apple.com/forums/thread/702420), Mar 2022):
*"The profile I just created expires on 15 Mar 2040"* — Mar 2022 + 18 years exactly.

### 2.3 Validity of the other profile types (relevant to the fallbacks)

| Profile type | Validity | Source |
|---|---|---|
| Developer ID (post-2017-02-22) | **18 years** | Documented above |
| Developer ID (pre-2017-02-22) | Until the Developer ID certificate expires | Documented above |
| Apple Development / Mac App Development (paid ADP) | *"typically not more than a year"* | TN3125 — Apple gives no exact figure |
| Development, free Apple Developer account | 7 days | [Provisioning profile updates](https://developer.apple.com/help/account/provisioning-profiles/provisioning-profile-updates/) |
| Developer ID **certificate** | 5 years | [Developer ID support](https://developer.apple.com/support/developer-id/) |

Note the gap: **Apple never states the exact validity of a development profile.** One year is the
universally observed value but is not a documented figure. Treat "annual" as approximate.

---

## 3. What happens when the embedded profile expires

### 3.1 The documented answer: the app stops launching

[Developer ID support](https://developer.apple.com/support/developer-id/), under *"For apps that utilize advanced capabilities with a Developer ID provisioning profile"*:

> Gatekeeper will evaluate the validity of your Developer ID certificate when your application is installed and will evaluate the validity of your Developer ID provisioning profile **at every app launch**. As long as your Developer ID certificate was valid when you compiled your app, then users can download and run your app, even after the expiration date of the certificate. **However, if your Developer ID provisioning profile expires, the app will no longer launch.**

[Certificates support page](https://developer.apple.com/support/certificates/):

> If your Mac application utilizes a Developer ID provisioning profile to take advantage of advanced capabilities such as CloudKit and push notifications, you must ensure your Developer ID provisioning profile is valid in order for installed versions of your application to run.

So of the ticket's two candidate answers — "HomeKit stops initialising" vs "the app keeps working" —
**neither is right. The app fails to launch outright.** The profile is a launch gate, not a
per-entitlement degradation. No Apple source suggests individual entitlements quietly stop being
honoured while the process continues.

**Inferred (moderate confidence):** the failure surface is an AMFI / code-signing launch rejection
(`Termination Reason: Namespace CODESIGNING, Code 0x1`), based on crash reports in
[thread 130919](https://developer.apple.com/forums/thread/130919) plus TN3125's description of the
check. Apple does not document the exact failure mode.

### 3.2 Apple contradicts itself, and never resolved it

Recorded for completeness because it cuts against §3.1. Quinn, Apr 2020
([thread 130919](https://developer.apple.com/forums/thread/130919)):

> Finally, I want to be clear about one thing: While Developer ID certificates and provisioning profiles have an expiry date, the system is meant to ignore them. There have been circumstances where that's not happened, but such problems are bugs. A Developer ID-sign product should not expire.

> There was a problem like this a year or two ago… and the immediate fix was for us to push out the expiration date on profiles until 2038. This is what you can see with my profile. My recollection is that this was an expedient measure, and that the plan was to change the OS to ignore profile expiry for Developer ID apps.

In that same thread a developer's app genuinely *did* fail to launch on expiry
(`Namespace CODESIGNING, Code 0x1`), filed as FB7678285 — real observed hard failure, which Quinn
classified as a bug rather than intent.

But Quinn reverts to the documented behaviour in Mar 2022
([thread 702420](https://developer.apple.com/forums/thread/702420)):

> A Mac program needs a provisioning profile if it claims any entitlements that must be authorised by that profile. **If your program needs a profile, it'll stop working when that profile expires.** For this reason, Developer ID profiles have a *long* expiry date.

**Unresolved.** No Apple source dated after March 2022 addresses whether the OS actually enforces
profile expiry for Developer ID, or whether the 2020 plan to make it ignore expiry ever shipped.
Certainty here is genuinely low in *both* directions.

**Practically it does not matter for this project.** With an 18-year window plus Apple's belt-and-braces
2038/2040 pushout, expiry is beyond any planning horizon. The risk lives entirely in pre-Feb-2017
profiles, which is not a situation this project can be in.

### 3.3 Certificate expiry is a separate and benign concern

[Developer ID support](https://developer.apple.com/support/developer-id/):

> Gatekeeper will evaluate the validity of your Developer ID certificate when your application is installed. As long as your Developer ID certificate was valid when you compiled your app, then users can download and run your app, even after the expiration date of the certificate. However, you'll need a new certificate to sign updates and new applications.

[Certificates support page](https://developer.apple.com/support/certificates/):

> If your certificate expires, users can still download, install, and run versions of your Mac applications that were signed with this certificate. […] If your certificate is revoked, users will no longer be able to install applications that have been signed with this certificate.

Membership lapse is likewise benign
([Create Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)):
*"If your membership expires, users can still download, install, and run your applications signed with Developer ID."*

**Revocation is the only true kill switch:** *"Any Developer ID app signed with a certificate that has been revoked can no longer be installed nor launch if it's already installed."*

**Correction to a common claim:** notarisation does **not** act as the timestamp. What makes
"valid at signing time" checkable is the **secure timestamp** (`--timestamp`, RFC-3161 from
`timestamp.apple.com`), which notarisation *requires* but is not synonymous with. No Apple doc says
notarisation itself serves this role; that framing appears only in forum paraphrase. Cite
`--timestamp` instead.

**One unresolved Apple self-contradiction on `.pkg` installers**, if installer-based distribution is
ever considered:

- [Developer ID support](https://developer.apple.com/support/developer-id/): *"Your installer package will only launch if your Developer ID Installer certificate is valid. Installer packages signed with a Developer ID Installer certificate that has expired must be re-signed…"*
- [Certificates](https://developer.apple.com/support/certificates/): *"If your certificate expires, users can still install packages that were signed with this certificate as long as the package includes a trusted timestamp."*

Directly contradictory, unresolved by Apple. Treat as open risk; prefer a `.zip`/`.dmg` over `.pkg`.

---

## 4. Notarisation

**Notarisation imposes nothing extra on restricted entitlements, and nothing at all on Catalyst.**

[Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
lists exactly seven required protections. The entitlement-related ones are only:

> Don't include the `com.apple.security.get-task-allow` entitlement with the value set to any variation of `true`.

> Ensure your processes have properly-formatted XML, ASCII-encoded entitlements as described in Ensure properly-formatted entitlements.

Plus the signing requirements:

> Use a 'Developer ID' application, kernel extension, system extension, or installer certificate for your code-signing signature. (Don't use a Mac Distribution, ad hoc, Apple Developer, or local development certificate.)

> Enable the Hardened Runtime capability for your app and command line targets…

> Include a secure timestamp with your code-signing signature. (The Xcode distribution workflow includes a secure timestamp by default.)

[Resolving common notarization issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)
has these sections and no others: valid code signature · valid Developer ID certificate · secure
timestamp · avoid `get-task-allow` · macOS 10.9 SDK or later · hardened runtime · stapler issues ·
properly formatted entitlements · external dependencies. The only entitlement-related rejection
messages documented are *"The executable requests the com.apple.security.get-task-allow entitlement"*
and *"Embedded entitlements are invalid: syntax error near line 1"*.

**Neither page mentions provisioning profiles at all.** There is therefore **no documented check
that entitlements are authorised by the embedded profile at notarisation time.** And Apple is explicit
that the notary is not a policy reviewer:

> Notarization of macOS software is not App Review. The Apple notary service is an automated system that scans your software for malicious content, checks for code-signing issues, and returns the results to you quickly.

**Inferred (well-supported):** a build carrying an unauthorised restricted entitlement can pass
notarisation and then fail at launch — these are separate gates. So notarisation success would be a
**false negative** for this problem. Do not treat "it notarised" as evidence HomeKit will work.

**No Catalyst-specific notarisation rules exist** — the string "Mac Catalyst" does not appear in the
notarisation documentation.

**Hardened runtime does not interact with restricted entitlements**: TN3125 places
hardened-runtime configuration entitlements in the *unrestricted* bucket. One documented wrinkle if
plug-ins are ever used: *"Plug-ins don't declare their own entitlements. Instead, they inherit the
entitlements of the host process. Therefore, a host app must include all the entitlements that
prospective plug-ins require."* Relevant to the deferred AppKit-plugin status-bar idea.

**Where the failure actually lands (inferred):** earliest, at **profile issuance / export** — the
portal refuses to mint a Developer ID profile allowlisting HomeKit, and `xcodebuild -exportArchive`
emits *"HomeKit capabilities are not available for Mac Catalyst Developer ID provisioning profiles."*
You never reach the notary.

---

## 5. `NSHomeKitUsageDescription` and App Sandbox

**No interaction with any of the above is documented.**

- **No App Sandbox entitlement exists for HomeKit.** The full topic list of
  [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox) contains **zero**
  occurrences of "HomeKit". The resource-access set is `network.server`, `network.client`,
  `device.camera`, `device.microphone`, `device.usb`, `print`, `device.bluetooth`,
  `personal-information.addressbook`, `personal-information.location`,
  `personal-information.calendars`, plus file/asset keys. There is no
  `com.apple.security.personal-information.homekit`. HomeKit is gated by the *capability*
  entitlement, not a sandbox exception.
- **The purpose string is a crash-avoidance requirement only.**
  [Enabling HomeKit in your app](https://developer.apple.com/documentation/homekit/enabling-homekit-in-your-app):
  *"If you don't include a purpose string, your app crashes when you first try to use HomeKit."*
  Xcode's capability record agrees: `"isRequiredInPlist": true`.
- **Sandbox entitlements are unrestricted**, so enabling the sandbox never itself forces a profile
  (TN3125). The constraint on a Developer ID Catalyst app comes from the capability table alone.
- **Correction to a map "verified fact".** The map states *"Mac Catalyst mandates App Sandbox on
  macOS."* What Apple actually documents is weaker:
  [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
  — *"When you use Mac Catalyst to enable your iPad app to run in macOS, Xcode automatically adds the
  App Sandbox and Hardened Runtime capabilities to the macOS target"* — and
  [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox) — *"To distribute a
  macOS app through the Mac App Store, you must enable the App Sandbox capability."* So: **automatic
  by default, and mandatory for the Mac App Store.** Whether a *Developer ID* Catalyst app may remove
  it is **undocumented** — no Apple statement forbids it. Since the recommended paths below are App
  Store or TestFlight, the sandbox is mandatory in practice regardless, and the map's operating
  assumption is safe. But the *reason* is App Store distribution, not Catalyst.

Runtime signals if HomeKit access is absent, from the local SDK (`HMError.h`):
`HMErrorCodeMissingEntitlement = 80`, `HMErrorCodeHomeAccessNotAuthorized = 47`, and
`HMHomeManagerAuthorizationStatusRestricted` ("Access to home data is currently restricted by the
system"). These are the codes to assert against when validating any signing configuration.

---

## 6. Fallbacks, ranked

Ranked for *this* project specifically: a headless daemon on **one Mac the maintainer owns**, with
no third-party users. That changes the calculus completely — the usual objection to development
signing (undistributable) is nearly free here.

### Rank 1 — Local development signing (Mac App Development profile)

- **HomeKit:** works. `DEVELOPMENT` is in `distributionTypes`; the repo's existing PoC already proves it.
- **Expiry cost:** profile *"typically not more than a year"* (TN3125; Apple states no exact figure).
  Rebuild/re-sign roughly annually — a one-command `xcodebuild` re-run, no Apple round-trip.
- **Requires:** the target Mac registered in the team device list. Paid ADP (have it: `FRB6K6JADV`).
- **Gives up:** notarisation (development certs are explicitly disallowed by the notary), Gatekeeper
  distribution to anyone else, and the map's "shipped, notarised, direct download" phrasing.
- **Keeps:** everything else — launchd daemon, local HTTP server, bearer token, no App Review, no
  sandbox-imposed rework beyond what Catalyst already does, full freedom over the API surface and
  destructive writes.
- **Why rank 1:** lowest total friction, zero external gatekeeper, and the only path with no
  third-party approval risk. For a single-machine self-hosted daemon, annual `xcodebuild` is a
  smaller tax than App Review on a local HTTP server.

### Rank 2 — Mac App Store

- **HomeKit:** works. `STORE` in `distributionTypes`; HomeKit is ✓ under ADP.
- **Expiry cost:** none once shipped. This is the only path with no recurring re-signing.
- **Costs:** App Review, on an app whose entire purpose is an authenticated local HTTP server
  granting an agent destructive control of the home. Sandbox mandatory. `/usr/local/bin/apple-bridge`
  ceases to exist; `keys.json` moves into the container; launchd registration must go through
  `SMAppService`. Public listing of a personal tool.
- **Unverified:** whether a MAS-delivered app embeds an expiring profile at all. Apple re-signs apps
  for App Store delivery, and MAS HomeKit Catalyst apps demonstrably do not expire, but I found no
  Apple statement on the embedded-profile lifecycle for MAS builds. Not load-bearing — observed
  behaviour is that they keep working.
- **Why rank 2:** strictly the most durable answer, but the review risk is real and the scope cost
  (out-of-scope per map: *"Mac App Store distribution. Developer ID chosen instead."*) is the largest
  of any option.

### Rank 3 — TestFlight (internal testers only)

- **HomeKit:** works — same `STORE` path, and TN3125 notes TestFlight *always* requires a profile.
- **Expiry cost:** **90 days per build.** [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview):
  a build can be tested for up to 90 days and becomes unavailable to testers after that; upload a new
  build to continue. So a mandatory upload-and-reinstall cycle at least quarterly, each requiring an
  App Store Connect round-trip.
- **Costs:** App Store Connect app record. Internal-only testing avoids Beta App Review. Requires
  Xcode 13+ for Mac builds (satisfied).
- **Why rank 3:** gets HomeKit without App Review, but 90-day churn on a daemon meant to survive
  reboots unattended is worse than rank 1's annual churn, and it adds a cloud dependency rank 1
  doesn't have.

### Not viable

| Path | Why it fails |
|---|---|
| Developer ID + HomeKit | The subject of this document. Portal will not issue the profile. |
| Developer ID app + HomeKit helper process | Helper still needs a Developer-ID-compatible profile allowlisting HomeKit. None exists. Mixing signing identities also breaks notarisation. |
| Ad-hoc / self-signed with the entitlement forced in | Restricted entitlement fails signature validation at launch; Catalyst additionally needs a profile for the data protection keychain. |
| Apply to Apple for Developer ID HomeKit | `canRequestFromPortal: false`, `distributionApprovalRequired: false`. No approval path exists. |
| Native macOS target instead of Catalyst | `HomeKit.framework` is `API_UNAVAILABLE(macos)`; only exists in the Catalyst slice. |
| Matter entitlement as a substitute | `MATTER_ALLOW_SETUP_PAYLOAD` is Developer-ID-eligible but only covers accessory setup payloads, not home-database read/write. Pairing is out of scope anyway. |

### Recommendation

**Rank 1 (development signing) for the map's destination, with rank 2 (Mac App Store) held as the
answer if the project ever needs to reach another person's Mac.** Replace the map's standing
constraint *"Distribution: Developer ID, notarised, direct download"* with something like
*"Development-signed local build, re-signed annually; Mac App Store if distribution is ever needed."*
Drop "notarised" from the destination — it is unreachable together with HomeKit.

---

## 7. Residual unknowns and the tests that would settle them

The verdict on Q1 is settled to the limit of what documentation can settle. These remain open:

1. **Definitive proof at the portal (30 minutes, decisive).** Enable the "Mac" capability on the iPad
   App ID, then attempt to create a **Developer ID** provisioning profile for the derived
   `maccatalyst.*` App ID with HomeKit enabled. Expected: HomeKit is absent from the profile's
   allowlist, or the App ID does not appear in the Developer ID profile picker at all. Verify the
   minted profile with:
   ```
   security cms -D -i embedded.provisionprofile | plutil -p - | grep -i homekit
   ```
   Absence of `com.apple.developer.homekit` from the `Entitlements` dict is the direct confirmation.
2. **Proof at export (equally decisive).** Archive the Catalyst target with the HomeKit entitlement and
   run `xcodebuild -exportArchive` with `method: developer-id`. Expected failure:
   *"HomeKit capabilities are not available for Mac Catalyst Developer ID provisioning profiles.
   Disable these features and try again."*
3. **Whether the notary would accept it anyway.** Force-sign with the entitlement, notarise, install,
   and observe. Expected: notarisation succeeds, then launch fails (`Namespace CODESIGNING`) or
   `HMHomeManager` reports zero homes / `HMErrorCodeMissingEntitlement`. Worth doing only to confirm
   that notarisation success is not evidence of anything.
4. **Exact development-profile validity.** Undocumented. Read `ExpirationDate` from the actual minted
   profile via the `security cms -D` command above rather than assuming 365 days.
5. **Whether modern macOS truly enforces Developer ID profile expiry** (§3.2). Unresolvable from docs.
   Would need a network-isolated Mac with the clock advanced past an expiry date. Academic given the
   18-year window; not worth the time.
6. **MAS-delivered embedded-profile lifecycle** (rank 2). Undocumented; observed behaviour suggests
   no expiry.
7. **A binding answer.** A DTS code-level support request quoting team `FRB6K6JADV` would produce an
   authoritative statement. Given four concurring primary sources, this is belt-and-braces — but it is
   the only route to something citable as official if the decision is ever challenged.

Tests 1 and 2 are cheap and would convert this verdict from "high confidence, documented" to
"empirically confirmed on our own team". **Recommended before rewriting the map's distribution
constraint.**

---

## Sources

Primary — Apple documentation and Developer Account Help:

- [Supported capabilities (macOS)](https://developer.apple.com/help/account/reference/supported-capabilities-macos/) — the decisive table
- [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)
- [TN3125: Inside Code Signing: Provisioning Profiles](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)
- [Developer ID — Apple Developer Support](https://developer.apple.com/support/developer-id/)
- [Certificates — Apple Developer Support](https://developer.apple.com/support/certificates/)
- [Create Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates)
- [Provisioning profile updates](https://developer.apple.com/help/account/provisioning-profiles/provisioning-profile-updates/)
- [Create a development provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-a-development-provisioning-profile/)
- [Create a Mac version of an iPad app](https://developer.apple.com/help/account/capabilities/create-a-mac-version-of-an-ipad-app/)
- [Creating distribution-signed code for macOS](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac)
- [Distributing your app for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Resolving common notarization issues](https://developer.apple.com/documentation/security/resolving-common-notarization-issues)
- [HomeKit Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.homekit)
- [Configuring HomeKit access](https://developer.apple.com/documentation/xcode/configuring-homekit-access)
- [Enabling HomeKit in your app](https://developer.apple.com/documentation/homekit/enabling-homekit-in-your-app)
- [HomeKit framework](https://developer.apple.com/documentation/homekit)
- [NSHomeKitUsageDescription](https://developer.apple.com/documentation/bundleresources/information-property-list/nshomekitusagedescription)
- [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Creating a Mac version of your iPad app](https://developer.apple.com/documentation/uikit/creating-a-mac-version-of-your-ipad-app)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)

Primary — local toolchain (Xcode 26.4, 17E192):

- `/Applications/Xcode.app/Contents/SharedFrameworks/DVTPortal.framework/Versions/A/Resources/DVTPortalCachedPortalCapabilities.json`
- `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.4.sdk/System/iOSSupport/System/Library/Frameworks/HomeKit.framework/Headers/` (`HMHomeManager.h`, `HMError.h`)

Corroboration only — Apple Developer Forums (never the sole basis for a claim above):

- [Changes to Developer ID Provisioning Profiles — Apple Staff, Feb 2017](https://developer.apple.com/forums/thread/73021)
- [Unable to export HomeKit app on Mac Catalyst — Jun 2020](https://developer.apple.com/forums/thread/651207) — the observed error message
- [Expired certificates now prevent app launch — Quinn/DTS, Apr 2020](https://developer.apple.com/forums/thread/130919)
- [Catalyst Requires Code Signing? — Quinn/DTS, Jan 2022](https://developer.apple.com/forums/thread/699085)
- [Know expiration date of Developer ID profile — Quinn/DTS, Mar 2022](https://developer.apple.com/forums/thread/702420)
- [Catalyst Developer ID support for Shared with You — Sep 2022](https://developer.apple.com/forums/thread/713677)
- [App Store Connect blocking device name entitlement on Catalyst](https://developer.apple.com/forums/thread/718657)
- [Trouble direct-distributing macOS app — DTS, Aug 2024](https://developer.apple.com/forums/thread/761458) — DTS points to the capability table
- [HomeKit support on macOS — Quinn/DTS + DTS](https://developer.apple.com/forums/thread/822517)
- [Finding a Capability's Distribution Restrictions — Quinn/DTS](https://developer.apple.com/forums/thread/721563)
