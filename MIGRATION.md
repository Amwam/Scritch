# SwiftUI Migration

Working document for the ongoing migration of Scritch's UI from AppKit (XIB + storyboard +
`NSViewController`) to SwiftUI. Written so that an agent or human with no prior context can pick
this up mid-flight.

**Branch:** `swiftui-migration` (off `main`)
**Started:** 2026-07-27
**Status:** Phases 0–4a complete and fully verified — build green, 36 unit tests and all 17
XCUITests passing. Phase 4b (the `SourceEditor` swap) is deferred.

---

## Goal

Move all UI to SwiftUI, phase by phase, with the app buildable, runnable and committed at every
step. No phase is allowed to leave the app broken.

The app itself is a scriptable scratchpad: paste text into an editor, press ⌘B, search a popover of
JavaScript transformation scripts, pick one, and it rewrites the text in place. No files, no tabs,
no documents — `DOING.md` explicitly rules those out, which is why a single `Window` scene is
sufficient.

## Ground rules

- **One commit per phase**, unsigned (`git commit --no-gpg-sign`). Do not push without being asked.
- **Every phase must build and be verified before the next starts.** "It compiles" is not
  verification for UI work.
- **No behaviour changes** unless explicitly agreed. This is a migration, not a redesign.
- Preserve UserDefaults keys and stored formats exactly — existing users' preferences must survive.

---

## Environment and invocations

Deployment target is **macOS 14.0** (raised from 13.0 in `258f804` to get `.onKeyPress` and
`@Observable`). Swift 5. Xcode project at `Scritch/Scritch.xcodeproj`.

Build — this exact form is required:

```sh
cd /Users/amit/Developer/Boop && xcodebuild \
  -project Scritch/Scritch.xcodeproj -scheme Scritch -configuration Debug \
  -destination 'platform=macOS' \
  -clonedSourcePackagesDirPath /Users/amit/Developer/.spm-cache-scritch \
  -skipPackagePluginValidation build
```

Test — same flags, `test` instead of `build`.

- `-skipPackagePluginValidation` is needed because CodeEditSourceEditor pulls in a SwiftLint
  build-tool plugin that fails non-interactive builds.
- `-clonedSourcePackagesDirPath` avoids intermittent corruption of SwiftTreeSitter's grammar
  submodules in the default DerivedData `SourcePackages`.

Run the app:

```sh
open /Users/amit/Library/Developer/Xcode/DerivedData/Scritch-dcobsqzlzubcwxggyiyoovjzkyyh/Build/Products/Debug/Scritch.app
pkill -f "Scritch.app/Contents/MacOS"   # always clean up
```

## Known traps

These have each cost real time. Read them.

- **Two trailing `Running SwiftLint for …` command failures are PRE-EXISTING and expected.** The
  build still reports `** BUILD SUCCEEDED **`. Ignore them; they are not your regression.
- **SourceKit diagnostics in this repo are chronically stale.** They routinely report
  `Cannot find type X in scope` for untouched, existing types. Trust `xcodebuild` only.
- **The `Scritch (App Store)` target does not build.** Pre-existing: `Unable to find module
  dependency: 'Rearrange'` from `TextStory`. Confirmed against a clean tree. Keep its pbxproj
  entries consistent, but you can only verify the main `Scritch` target.
- **`ScritchTests/LanguageDetectorTests.swift` and `ScriptManagerTests.swift` are not listed in the
  pbxproj group**, yet their tests execute. Don't be confused by this when editing that target.
  (`AppModelTests.swift`, added in Phase 4a, *is* correctly registered in the group.)
- **A stale Xcode `debugserver` can silently capture app launches.** Symptom: the process sits in
  state `SX` with `ppid != 1`, and `kill -9` will not reap it — only the tracer can release a
  traced+stopped process. Fix: press Stop (⌘.) in Xcode. **Do not kill the user's Xcode
  processes**; that drops their debug session.
- **`Package.resolved` can be deleted as a side effect** of building with
  `-clonedSourcePackagesDirPath`. Restore it before committing so it stays out of the diff.
- **`osascript` has `keystroke` permission but not assistive access for `click at`.** GUI
  automation from the shell is therefore only partially usable — this is precisely why the XCUITest
  suite exists.
- **New `.swift` files must be hand-registered in `project.pbxproj`** (PBXFileReference, two
  PBXBuildFiles, both targets' Sources phases, and the group). There is no Xcode automation here.
  Object ID convention in use: `FA0000000000000000000C..`. Allocated so far: `C0x`–`CFx`.
  **Next free prefix: `D0x`.** Verify edits with `plutil -lint`.
- **`MainMenu.xib` is gone** (deleted in Phase 4a), so the old "verify XIB edits parse" check no
  longer applies. There are no XIBs or storyboards left in the project.

---

## Architecture: the bridging pattern

**Historical, for Phases 0–3.** While the app was still `@NSApplicationMain` with `MainMenu.xib`,
SwiftUI views were embedded into the AppKit hierarchy via `NSHostingView`, and each converted area
followed the same shape (Phase 4a removed the last of these hosting shims):

> An `ObservableObject` model owns the state and behaviour. AppKit code writes to the model; the
> SwiftUI view observes it. Consumers hold a **settable** `var model: Model = .shared` so Phase 4
> can swap in `@Environment` injection without touching call sites.

Models introduced so far, all in `Scritch/Scritch/System/`:

| Model | Owns | Bridges |
|---|---|---|
| `StatusStore` | `Status` enum, message queue, 10s display timing | `ScriptManager`, `UpdateBuddy`, `PopoverViewController` → `StatusBarView` |
| `EditorLanguageModel` | current language, auto/manual mode, `displayName(for:)` | `CodeEditorView` → `LanguageStatusBarView` |
| `ScriptPickerModel` | `isPresented`, query, results, selection, focus, list height | `PopoverViewController` → `ScriptPickerView` |
| `AppModel` | the whole object graph the XIB used to instantiate; picker/script/editor actions | `ScritchApp`, `ScritchCommands`, `ContentView`, `AppDelegate` |

As of Phase 4a the bridging pattern is inverted: SwiftUI owns the app, and `AppModel` is the single
coordinator that the remaining AppKit shim (`AppDelegate`) reaches into via `AppModel.shared`.

---

## Phase log

### Prep — `258f804` Raise deployment target to macOS 14.0
Unlocks `.onKeyPress` and `@Observable`. All six build configs.

### Phase 0 — `644b60a` Extract `StatusStore` from `StatusView`
`ScriptManager`, `UpdateBuddy` and `PopoverViewController` each held
`@IBOutlet weak var statusView: StatusView!`, so the system layer depended on a concrete view.
Extracted the `Status` enum, queue and timing into `System/StatusStore.swift`; `StatusView` became
a pure renderer. Three outlet connections surgically removed from the XIB.

### Phase 1 — `d7b9ac0` Preferences storyboard → SwiftUI
Deleted `Scritch/UI/Preferences.storyboard` (298 lines) and all three preference view controllers.
Added `Views/Settings/SettingsView.swift`, `System/ThemeSettings.swift` (holding
`ScritchColorScheme` + `applyTheme()`), and `Views/Settings/SettingsWindowController.swift`.

Because there is no `App` struct yet, the `Settings` **scene** cannot be used; the SwiftUI view is
hosted in an `NSHostingController` inside an `NSWindowController` singleton, presented from
`AppDelegate.showPreferencesWindow(_:)`.

Two deliberate calls:
- `@AppStorage` is used for `scritchColorScheme` (an `Int` rawValue) but **deliberately NOT** for
  the scripts-folder URL — `@AppStorage`'s URL encoding differs from `UserDefaults.set(_ url:forKey:)`
  and would have silently broken existing users' saved folder.
- The "Set Default Location" button was dropped: it was `hidden="YES"` in the storyboard and its
  action only showed an alert and returned. Dead UI.

### Phase 2 — `f7983fb` Both status bars → SwiftUI
Added `Views/StatusBarView.swift`, `Views/LanguageStatusBarView.swift`,
`System/EditorLanguageModel.swift`. Deleted `Views/LanguageStatusBar.swift` and
`Views/UpdateTextField.swift`.

`StatusView.swift` survives as a 46-line `NSHostingView` shim **and must stay for now**: it is the
`customView` of a toolbar item referenced from `allowedToolbarItems`/`defaultToolbarItems`, so
deleting it would mean rebuilding the toolbar item. It dies naturally in Phase 4.

`displayName(for:)` was carried over verbatim — it has hand-tuned special cases (C++, C#,
Objective-C, JSON, OCaml Interface, …). Do not regenerate it.

### Phase 3 — `1c5f1cc` Script picker popover → SwiftUI
Added `System/ScriptPickerModel.swift`, `Views/ScriptPickerView.swift`. Deleted seven AppKit files:
`OverlayView`, `PopoverContainerView`, `PopoverView`, `SearchField`, `ScriptTableView`,
`ScriptTableViewCell`, `ScriptsTableViewController`. `PopoverViewController` shrank 184 → 111 lines.
The XIB's entire popover subtree collapsed to one plain `customView`.

**The `NSEvent.addLocalMonitorForEvents` keyboard monitor is gone entirely** — replaced by
`.onKeyPress` handlers applied to both focusable areas. Escape is handled by both
`.onKeyPress(.escape)` and `.onExitCommand` (escape is often routed as a cancel action first);
`model.dismiss()` is guarded on `isPresented` so double delivery is harmless.

Behaviour deliberately preserved:
- List height is exactly `45 * min(5, count) + (count != 0 ? 20 : 0)`.
- `selectedScript` falls back to `results.first` — this is what makes "type and hit Enter" work,
  and it is load-bearing UX.
- Tab/Shift-Tab always return `.handled` so focus can never escape into the document.

Verified at runtime: ⌘B opens, search field takes focus, live filtering, Esc dismisses, status text
transitions, and a full `base64 enc` round-trip through the editor.

### Phase 4a — SwiftUI app shell

**Scope was deliberately split.** MIGRATION.md's original Phase 4 bundled the app shell together
with replacing `CodeEditorView` with the package's `SourceEditor`. Those were separated:

- **4a (this phase):** items 1–4 and 6 — the `App` struct, `.commands`, the `Settings` scene, the
  toolbar, and `EditorLanguageModel` moving out of controller code.
- **4b (deferred, and arguably should be dropped):** item 5, the `SourceEditor` swap. See
  "Why 4b is deferred" below.

Added:

| File | Role |
|---|---|
| `ScritchApp.swift` | `@main App`; `Window` scene + `Settings` scene; `NSApplicationDelegateAdaptor` |
| `ScritchCommands.swift` | `Commands` — everything `MainMenu.xib` customised |
| `System/AppModel.swift` | the coordinator; owns the object graph the XIB used to instantiate |
| `Views/ContentView.swift` | the window: editor + language bar + picker overlay + toolbar |
| `Views/EditorRepresentable.swift` | 5-line `NSViewRepresentable` over `CodeEditorView` |

Deleted: `MainViewController.swift`, `PopoverViewController.swift`, `StatusView.swift`,
`SettingsWindowController.swift`, and `UI/Base.lproj/MainMenu.xib`. `Info.plist`'s `NSMainNibFile`
key was removed — a SwiftUI `@main` app will fail to launch with it still present.

Decisions worth knowing:
- **`AppModel` is a singleton** (`private init()`, `.shared`). Not for convenience: the Services
  provider (`AppDelegate.textServiceHandler`, named by `Info.plist`'s `NSServices` entry) has no
  SwiftUI environment to read from and needs some way in.
- **One `CodeEditorView` instance for the app's lifetime**, owned by `AppModel` and handed to
  SwiftUI by `EditorRepresentable`. If the representable constructed its own, every SwiftUI rebuild
  would drop the document, undo stack and language state.
- **The Open/Close Picker menu swap** — previously `AppDelegate.setPopover(isOpen:)` toggling
  `isHidden` — is now `if model.isPickerOpen` inside `CommandMenu("Scripts")`, driven by an
  `@Published` mirror of `pickerModel.isPresented`.
- **"@OKatBest on Twitter" is reproduced as a disabled no-op.** Checked the XIB before deleting it:
  that item had no `<connections>` block at all, so AppKit auto-disabled it. It was always dead UI;
  it was not wired to a URL that got lost in translation.
- `hide()`'s old `asyncAfter` un-hiding hack and `PopoverViewController`'s `view.isHidden` juggling
  are gone — SwiftUI removes the overlay from the hierarchy itself. The `DispatchQueue.main.async`
  before setting `focus = .search` **was kept**; SwiftUI still needs a run-loop turn to install the
  text field before it can take the keyboard.

#### Verification status

- ✅ `** BUILD SUCCEEDED **`
- ✅ **36 unit tests, 0 failures** (23 pre-existing baseline + 13 new `AppModelTests`)
- ✅ **17 XCUITests, 0 failures** — the full oracle, run after the fact once a display was available

The UI suite initially reported one failure,
`testPreferencesWindowTabsAndColorSchemePersistence`, which took three fixes. All three were
consequences of hosting `SettingsView` in a `Settings` scene rather than an `NSWindowController`;
none was a functional regression:

1. **Tab identifiers stopped resolving.** The scene renders the `TabView` as a preferences
   *toolbar*, and `.accessibilityIdentifier` on the `Label` inside `.tabItem` does not survive that
   transformation. Fixed by locating the tabs by visible label — see the contract note above.
2. **Both tab bodies are built eagerly**, so `settings.colorSchemePicker` exists in the
   accessibility tree even while the Scripts tab is showing. The test had used existence as a proxy
   for "which tab is active"; it now uses `isHittable`, which is what it actually meant.
3. **The scene persists the selected tab** under
   `com_apple_SwiftUI_Settings_selectedTabIndex`, which leaked between runs and made the app start
   on the Colors tab. Added to `resetStateForUITestsIfRequested()` — the old NSWindowController
   didn't persist tab selection at all, so the hook had never needed it.

#### Known wart: window frame autosave

`AppDelegate` still saves/restores under `scritch.app.window`, but that key is **never written** —
the app's defaults contain `NSWindow Frame main` and no `NSWindow Frame scritch.app.window`. The
`Window("Scritch", id: "main")` scene autosaves the frame itself under its scene id, and wins.

User-visible behaviour is correct (the frame *is* restored), so this is not urgent, but two things
follow: existing users' frame saved under the old key is orphaned — a one-time window-position reset
on upgrade — and the `AppDelegate` autosave code is now effectively dead. Either delete it and let
the scene own the frame, or set the scene's autosave name to `scritch.app.window` to preserve
continuity. Not done here because it is a behaviour question, not a mechanical one.

#### Why 4b is deferred

`CodeEditorView` is already a facade over `TextViewController`, which is exactly what `SourceEditor`
wraps internally — so swapping it buys no architectural simplification. Against that it risks two
things the app depends on:

- `ScriptManager.replaceText` → `CodeEditorView.replace(ranges:with:)`, which walks ranges
  back-to-front inside one undo group. A `Binding<String>` cannot express that, and round-tripping
  the document through a String binding would collapse undo and break multi-cursor scripts.
- `editor.textView` carries the `editor.textView` accessibility identifier the entire XCUITest
  suite hangs off.

If 4b is ever revived, the `NSTextStorage` initialiser (not the `Binding<String>` one) plus a
retained `TextViewCoordinator` is still the right approach — but the honest recommendation is to
close it as "won't do" unless a concrete need appears.

---

## Current state

- XIB: 750 → 538 → **deleted**. No XIBs or storyboards remain in the project.
- Remaining AppKit interface-builder wiring: **zero** `@IBOutlet`/`@IBAction`/`@NSApplicationMain`
  references (the only grep hit left is the word `@NSApplicationMain` inside a comment in
  `ScritchApp.swift`).
- `AppDelegate` is down to 4 responsibilities: the UI-test state reset, `applyTheme()`, the Services
  provider, and window-frame autosave.

---

## Task list

| # | Phase | Status |
|---|---|---|
| 0 | Decouple system layer from `StatusView` | ✅ done (`644b60a`) |
| 1 | Preferences → SwiftUI | ✅ done (`d7b9ac0`) |
| 2 | Status bars → SwiftUI | ✅ done (`f7983fb`) |
| 3 | Script picker popover → SwiftUI | ✅ done (`1c5f1cc`) |
| — | **XCUITest suite** (regression oracle for Phase 4) | ✅ done (`b4c8acb`) |
| 4a | SwiftUI app shell, `.commands`, `Settings` scene, toolbar | ✅ done (`3eac0df` + follow-up) |
| 4b | `CodeEditorView` → `SourceEditor` | ⏸️ deferred — see "Why 4b is deferred" |

**Phase 4 workflow:** run the full suite green *before* starting, then again after. Any test that
goes red is either a real regression or a broken identifier — investigate, never weaken the test.

Both halves happened for 4a: green before, and green after (once a display was available — the
phase itself was implemented with the screen off, so the "after" run lagged the commit).

### XCUITest suite — `b4c8acb` (done)

Manual verification proved slow and unreliable, so `ScritchUITests` exists to act as the
before/after oracle for Phase 4. **17 UI tests + 23 unit tests, two consecutive fully green runs.**
A full run takes ~3 minutes and seizes the keyboard and mouse.

**Design constraint:** tests assert on user-visible behaviour and stable accessibility identifiers,
**never** on AppKit class names or view-hierarchy shape. Phase 4 deletes or rewrites nearly every
view class; a test that breaks on a rename is worse than no test, because it produces noise that
masks real regressions.

#### Accessibility identifier vocabulary — THE PHASE 4 CONTRACT

Phase 4 must keep every one of these resolvable, or the oracle silently stops testing:

| Identifier | Attaches to | Notes |
|---|---|---|
| `editor.textView` | the document text view (role `.textArea`) | set on the actual `CodeEditTextView.TextView`, **not** the wrapping `CodeEditorView` |
| `picker.scrim` | popover dimming background | tap dismisses |
| `picker.searchField` | popover search field | |
| `picker.resultsList` | popover results list | |
| `picker.row.<Script Name>` | one per script, keyed by exact `Script.name` | e.g. `picker.row.Base64 Encode`. Carries accessibility **value** `"selected"`/`""` for highlight state, so tests never assume row order — script load order is not guaranteed |
| `statusBar.message` | toolbar status pill | text exposed via accessibility **value**, not label |
| `languageBar.picker` | bottom language bar menu button | text exposed via explicit `.accessibilityValue(...)` — macOS does not reliably expose a SwiftUI `Menu`'s title to XCUITest |
| `settings.colorSchemePicker` | Preferences colour-scheme picker | |

Menu titles "Open Picker" / "Close Picker" / "Scripts" are treated as stable user-visible text
rather than identifiers. **The Preferences tab titles "Scripts" and "Colors" joined them in Phase
4a**: SwiftUI's `Settings` scene renders the `TabView` as a preferences *toolbar*, and an
`.accessibilityIdentifier` on the `Label` inside `.tabItem` does not survive that transformation —
the tabs arrive as plain buttons carrying only their title. There is no supported API to identify
them, so `UITestSupport.settingsTab(_:)` locates them by label. `settings.tab.scripts` /
`settings.tab.colors` are therefore **retired**; the identifiers are still set in `SettingsView.swift`
but are inert while the Settings scene hosts it.

The vocabulary is also documented in `ScritchUITests/UITestSupport.swift`'s header comment.

#### Test-only app hooks

- `AppDelegate` honours a `UITEST_RESET_STATE=1` launch-environment variable that wipes
  `editorLanguageMode` and the colour-scheme default on launch, so the sandboxed app's persisted
  UserDefaults don't leak between runs. No effect outside UI testing. **Phase 4 must carry this
  hook over** when `AppDelegate` is reduced to an `NSApplicationDelegateAdaptor`.

#### Known gaps — do not assume these are covered

- **Shift-Tab reverse-highlight is not asserted.** Forward Tab, Down-into-list and
  Up-back-to-search are all covered and exercise the same `moveSelection` path with a negative
  offset, but `typeKey(.tab, modifierFlags: .shift)` reproducibly failed to move the highlight in
  this environment and could not be root-caused as either an XCUITest key-synthesis limitation or a
  genuine app gap. **Worth one manual check before trusting Phase 4 blind.**
- The scripts-folder `NSOpenPanel` is not tested — file-picker sheets aren't practically
  automatable via XCUITest.
- Preferences persistence exercises Dark only, not all three schemes.

#### `testAAAWarmUpAppLaunch`

A deliberate infrastructure test, not a functional one. If a previous `Scritch.app` is still
attached to a live Xcode debug session, XCTest's pre-launch "terminate existing instance" step
fails and takes down whichever test runs first alphabetically. This warm-up absorbs that one hit
via `XCTExpectFailure` matched narrowly to `"Failed to terminate"`.

`options.isStrict = false` is **load-bearing**. It defaults to `true`, which would fail the test
with "expected failure did not occur" on a clean machine — tying the suite's greenness to the
*presence* of a stale debug session, exactly backwards. This was a real defect in the first
version of the suite and was fixed; don't let it regress.

### Next

Phase 4a is done and verified. Remaining threads, in priority order:

1. **Decide the window-frame autosave question** — see "Known wart" above.
2. **Shift-Tab reverse-highlight** in the picker: still never covered by the suite, still worth one
   manual check.
3. Phase 4b, if it is ever revived — but see "Why 4b is deferred".

For reference, the full suite is:

```sh
cd /Users/amit/Developer/Boop && xcodebuild \
  -project Scritch/Scritch.xcodeproj -scheme Scritch -configuration Debug \
  -destination 'platform=macOS' \
  -clonedSourcePackagesDirPath /Users/amit/Developer/.spm-cache-scritch \
  -skipPackagePluginValidation test
```

Needs the screen on; takes ~3 minutes and seizes keyboard and mouse. Use
`-only-testing:ScritchTests` for a headless unit-only run.

**A stale Xcode debug session will break the UI run** with "Timed out while enabling automation
mode" — check for a Scritch process in state `SX` whose parent is `debugserver`, and press ⌘. in
Xcode to release it.

---

## Deferred / out of scope

- **Phase 4b** — replacing `CodeEditorView` with `SourceEditor`. Rationale for deferring (and for
  probably dropping it) is under "Phase 4a → Why 4b is deferred".
- Fixing the `Scritch (App Store)` target's `Rearrange` module failure.
- Adding the two orphaned unit test files to the pbxproj group.
- `StatusView.fadeText(to:completionHandler:)` was dead code and was removed in Phase 2.
