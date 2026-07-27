# Pantrix Rorty — SwiftUI demo

A from-scratch **SwiftUI** sample app that integrates the published
[Pantrix iOS SDK](https://github.com/developersancho/pantrix-sdk-ios-spm) (`1.0.0-beta.14`) and uses the
[Rick & Morty REST API](https://rickandmortyapi.com/documentation#rest) as its data source. It is the
sibling of [`pantrix-rorty-ios-uikit-demo`](../pantrix-rorty-ios-uikit-demo) and covers the same SDK
surface from the other side of the framework divide.

It exists because the UIKit demo cannot answer two questions:

1. **What does a modern SwiftUI app see?** No `UIViewController`s to auto-track, no `AppDelegate`, a
   `NavigationStack` instead of a nav controller, `async/await` instead of callbacks.
2. **What does an app without Alamofire do?** This one has none — every request goes through
   `Pantrix.instrumentedSession()`, which observes a `URLSession` without re-issuing anything.

Both questions produced real SDK bugs. See [What this demo found](#what-this-demo-found).

## Stack

| Concern | Choice |
| --- | --- |
| UI | SwiftUI, `TabView` (5 tabs), `NavigationStack` per tab |
| Architecture | MVI (`State` / `Intent` / `Effect`) over clean layers — Domain / Data / UI |
| iOS base | 17.0 (`@Observable`) |
| Project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) — [`project.yml`](project.yml) is the source of truth |
| Networking | `URLSession` + `Pantrix.instrumentedSession()` — **no Alamofire** |
| Images | Kingfisher |
| DI | Resolver (`@Injected` only) |
| Telemetry | Pantrix — Core + SwiftUI + Crash + Inspector + Feedback |

---

# Wiring the SDK — step by step

Steps 1–3 are package setup, 4–8 are runtime, 9–11 are the SwiftUI-specific parts and the bits that only
matter once something crashes.

## 1. Add the SPM package

```yaml
packages:
  Pantrix:
    url: https://github.com/developersancho/pantrix-sdk-ios-spm
    exactVersion: "1.0.0-beta.14"
```

**`exactVersion`, not `from:`** — SPM's `from:` range excludes pre-releases, so `from: "1.0.0"` resolves to
nothing while every published version is a beta.

No Alamofire entry here, and that is the point of this demo. `PantrixAlamofire` ships as **source** so it
compiles against the consumer's copy; an app that has no Alamofire simply doesn't link that product.

## 2. Link the products

```yaml
dependencies:
  - { package: Pantrix, product: Pantrix }            # core umbrella
  - { package: Pantrix, product: PantrixSwiftUI }
  - { package: Pantrix, product: PantrixCrash }
  - { package: Pantrix, product: PantrixInspector }
  - { package: Pantrix, product: PantrixFeedback }
  - { package: Pantrix, product: PantrixInspectorNoop }
  - { package: Pantrix, product: PantrixFeedbackNoop }
```

The umbrella `Pantrix` does `@_exported import PantrixCore` and **nothing else** — the add-ons are opt-in
and not re-exported, so each is listed and imported explicitly. `import Pantrix` alone does not give you
`PantrixCrash.enable()`.

## 3. Swap the debug tools out of Release

Inspector and Feedback are development tools. Both ship a `-noop` twin with the identical API and an empty
body, selected by a compilation condition, so a Release build links the empty one and the call sites never
change:

```swift
#if PANTRIX_INSPECTOR
import PantrixInspector
#else
import PantrixInspectorNoop
#endif
```

## 4. One Pantrix project per build configuration

Three configurations, three bundle ids, three Pantrix projects — so QA traffic never lands in the
production project's numbers:

| Config | Bundle id | Display name |
| --- | --- | --- |
| Debug | `com.pantrix.demo.rorty.swiftui.debug` | PX Rorty SU Debug |
| QaTest | `com.pantrix.demo.rorty.swiftui.qatest` | PX Rorty SU QA |
| Release | `com.pantrix.demo.rorty.swiftui` | PX Rorty SwiftUI |

The ingest gate matches **bundle id ↔ the project's App ID exactly**; a mismatch is rejected, not merged.

## 5. Read the variant at runtime

[`Sources/App/BuildVariant.swift`](Sources/App/BuildVariant.swift) resolves the variant from
`SWIFT_ACTIVE_COMPILATION_CONDITIONS` and hands back that variant's SDK key.

**The SDK ingest key (`px_…`) is committed on purpose** — it ships inside the app and can be pulled out of
any IPA, so the backend treats it as public. The **CI key** is a different thing: it uploads dSYMs, it is
`key_type=CI`, and it lives only in a gitignored `.pantrixrc*` file. The two are never interchangeable.

## 6. Initialise at app start

SwiftUI has no `AppDelegate`. Initialisation goes in the `App` type's `init`, before any view exists —
[`Sources/App/PantrixRortySwiftUIApp.swift`](Sources/App/PantrixRortySwiftUIApp.swift):

```swift
@main
struct PantrixRortySwiftUIApp: App {
    init() {
        Pantrix.initialize(config: PantrixConfig(...))
        PantrixCrash.enable()
    }
}
```

**`config.enableRemoteConfig = true` makes everything above a request, not a decision.** Remote config is
a full override: a project with no SDK Config row gets the backend's baseline, which has
`trackHttpBody = false` and `keepSentEvents = false`. On a brand new project that silently turns body
capture off and deletes events after upload. Measured here: with the flag off a manual `trackHttp` carried
2719 bytes; with it on, the field never arrived. Set the project's SDK Config row before trusting the
local config.

## 7. HTTP tracking — the URLSession path

One line, in [`Sources/Data/Remote/RickMortyClient.swift`](Sources/Data/Remote/RickMortyClient.swift):

```swift
private let session = Pantrix.instrumentedSession()
```

Created **once** and reused: `instrumentedSession()` builds a delegate-backed `URLSession` and `URLSession`
retains its delegate until invalidated, so one per call leaks one per call.

It observes rather than re-issues, which buys two things the Alamofire monitor doesn't have — **failed
requests** (the monitor needs a response to build an event, so it drops them) and `protocol` / `dnsAddress`.
It costs one: **Apple never hands a response body to a data delegate for async or completion-handler
tasks**, so `responseBody` is always absent on this path. The Lab's three HTTP rows make the trade visible
in the data rather than describing it — including a row that attaches the body by hand with
`Pantrix.trackHttp(responseBody:)`.

Kingfisher uses its own internal session and is **not** tracked.

## 8. Screens — name them yourself

Automatic screen tracking watches `UIViewController` lifecycles. A pure SwiftUI app is **one**
`UIHostingController`, so the automatic tracker sees one screen for the entire app and never changes it.

So every root screen names itself, and pushed screens come from the navigation path:

```swift
List { … }.trackScreen("Characters")               // roots

NavigationStack(path: $path) { … }
    .trackNavigation(path: path)                   // pushed destinations
```

`trackNavigation` needs a **typed array** (`[Route]`), not `NavigationPath` — it has to read the elements
to name them. Each route names itself through `PantrixScreenNameProviding`, and
[`Route.pantrixScreenName`](Sources/App/Route.swift) is a **constant per case**: deriving it from an
associated value would put record ids into analytics.

A pushed screen must **not** also carry `.trackScreen`, or it is reported twice.

## 9. Interactions — four routes to one event

All four are in the app, deliberately, because which one is correct depends on what you're attaching to:

| Route | Where | Why there |
| --- | --- | --- |
| `.trackTaps(_:onLongPress:)` | Characters, Episodes rows | a plain view with no tap handler of its own |
| `trackedTap(_:perform:)` | Lab rows | the row **is** a `Button` — a modifier would add a second handler |
| `PantrixTrack.tap(_:)` | Locations **view model** | the screen keeps `List` + `Button`, so the interaction is emitted from the layer that decides |
| `trackedEditingChanged` / `trackFocus` | Profile's two text fields | `onEditingChanged` is a `TextField` parameter (iOS 13+); `trackFocus` reads a `@FocusState` you already own (iOS 15+) |

They all write the name under the same **`element`** key. A hand-rolled
`trackInteraction(.click, ["target": …])` would create a second vocabulary that no dashboard adds up.

Long-press on a character row is a real shortcut, not a demo hook: it skips the detail screen and opens
that character's episodes.

## 10. Scroll tracking needs a ScrollView, not a List

Episodes is the one list built as `ScrollView` + `LazyVStack`. `trackScroll` measures **one** content
view's offset inside the container's coordinate space, and a `List` never gives you one — its rows are
separate, lazily built and recycled. Characters and Locations stay `List`s so both shapes are in the app.

```swift
ScrollView {
    LazyVStack { … }
        .trackDrag("episodes_feed")     // leading edge: a drag began
        .trackScroll("episodes_feed")   // trailing edge: where it came to rest
}
.pantrixScrollContainer()               // the coordinate space to measure against
```

Without `pantrixScrollContainer()` on the container, `trackScroll` has no named space and reports nothing.

## 11. dSYM upload — a build phase

[`project.yml`](project.yml) runs `pantrix-upload-dsym.sh` as the **last build phase**, reading the
per-configuration `.pantrixrc*` credentials. Debug produces no dSYM (DWARF is in the binary), so the
script no-ops there and uploads only on QaTest/Release.

**The dSYM's project must be the crash's project.** Mixed up, the crash symbolicates to
`status: "missing"` and the rollup filters it out entirely — which reads exactly like the crash was never
captured. Output goes to `/tmp/pantrix-dsym-swiftui-buildphase.log`.

---

# Build & run

```bash
PANTRIX_DEV_TEAM=<your-team-id> xcodegen generate
```

Never run bare `xcodegen generate` — it wipes `DEVELOPMENT_TEAM` and breaks on-device signing.

```bash
open PantrixRortySwiftUI.xcodeproj
```

One scheme per variant — `PantrixRortySwiftUI-Debug` / `-QaTest` / `-Release`. All three install side by
side. Needs a Pantrix TEST backend on `http://localhost:8099`; on a physical device set
`PANTRIX_BACKEND_URL` to the Mac's LAN IP in the scheme's Run → Environment Variables.

# Verifying the integration

Screen names are the first thing to check, because the failure mode is silent:

```sql
SELECT screen_name, count() FROM PantrixDB_TEST.analytics_events
WHERE build_app_id LIKE '%rorty.swiftui%' AND event_name = 'screen_view'
GROUP BY screen_name;
```

Every row should be a real name (`Characters`, `CharacterDetail`, `Lab`, …). A single
`UIHostingController<…>` row instead means step 8 is not wired.

The HTTP trade-off, in one table:

```sql
SELECT JSONExtractString(event_attrs, 'client')                  AS client,
       length(JSONExtractString(event_attrs, 'responseBody'))    AS body_len
FROM PantrixDB_TEST.analytics_events
WHERE build_app_id LIKE '%rorty.swiftui%' AND event_type = 'network';
```

`urlsession` rows carry headers, timings, `protocol` and failures but `body_len = 0`; the
`urlsession-manual` row carries the body. That contrast is the point of the Lab's HTTP section.

**Crash path** — build QaTest (it produces a dSYM and uploads it), trigger a Crash Lab row, relaunch
(fatal crashes are reported on the *next* launch), and the crash should reach the rollup **symbolicated**:

```
crash_type: fatal_exception
type:       SIGTRAP
file:       CrashLabView.swift
line:       35
method:     closure #3 () in closure #2 () in closure #1 () in CrashLabView.body.getter
```

A crash that lands in `analytics_events` but never in `analytics_crashes` means its dSYM never arrived.

# What this demo found

Building it surfaced four SDK-side problems that the UIKit demo could not reach. All four are fixed.

| Finding | Why only here |
| --- | --- |
| **`trackScroll` emitted nothing on iOS 18+** — its offset went through `preference` / `onPreferenceChange`, which stops propagating during a scroll. Measured: the `GeometryReader` evaluated 162 times across one swipe (0 → 822pt) while `onPreferenceChange` fired **once**, with `0`. Fixed in `1.0.0-beta.14`. | Nothing else in the repo scrolled a tracked SwiftUI view |
| **`trackDrag` took the ScrollView's scrolling away** — a SwiftUI `DragGesture` says nothing to `UIScrollView`'s pan, whatever `simultaneousGesture` implies. Three full swipes moved the list by zero. It now owns a `UIPanGestureRecognizer` whose delegate allows simultaneous recognition. Fixed in `1.0.0-beta.14`. | Same |
| **Stack overflow reports `SIGBUS`, not `SIGSEGV`** on iOS — the guard page is a protection failure, and the record arrives with ~6 frames because there is no stack left to unwind. Three sibling demos carried the macOS answer. | Running the Crash Lab and reading the record instead of the label |
| **A new project's remote config silently overrides the app** — no SDK Config row means `trackHttpBody = false` and `keepSentEvents = false`, so body capture is off and the Inspector looks empty. | Three brand-new Pantrix projects, created for this demo |

Neither of the first two failed loudly, and both survived a green test suite: the SDK's unit tests drive
the extracted handlers and never exercise SwiftUI's delivery path. That is why `PantrixSwiftUI` is now
exempt from the SDK's coverage gate and guarded by a by-hand demo run in its release checklist instead.

# App structure

```
Sources/
  App/          entry point (SDK init), RootTabView, Route, BuildVariant, DI bootstrap
  Core/Mvi/     MviState/Intent/Effect, MviViewModel, PagedListViewModel
  Domain/       entities, repository protocols, use cases — Foundation only, no Codable
  Data/         DTOs, mappers, RickMortyClient (instrumentedSession), repository impls
  UI/
    Characters/ list (search + status filter + paging) → detail → episodes
    Locations/  list → detail → residents
    Episodes/   ScrollView feed (trackScroll + trackDrag) → detail → characters
    Profile/    the whole identity surface + two typed fields + theme picker
    Lab/        one row per SDK surface, CrashLab
    Shared/     row components, theme
  CrashLab/     ObjC / ObjC++ crash triggers — not expressible in Swift
```

Two architectural rules the code depends on:

- **All UI state lives in `State`.** `@Observable` observes the base class's `state` but **not** a
  subclass's own stored properties, and it compiles silently either way — measured, not assumed. A feature
  view model's stored properties are `@ObservationIgnored` collaborators.
- **`UI` never sees `Data`.** Only `App` knows both, at the DI registration. A view cannot reach a DTO or a
  `URLSession`.

# Status

**Complete.** Five Pantrix products exercised in real use: Core (events / screens / user / interactions /
exceptions / HTTP), SwiftUI (`trackScreen`, `trackNavigation`, `trackTaps`, `trackedTap`, `trackScroll`,
`trackDrag`, `trackHover`, `trackFocus`, `trackedEditingChanged`, `PantrixTrack.*`), Crash (four catcher
families, next-launch report, symbolication), Inspector (`present` + shake), Feedback (`show`).
