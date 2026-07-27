# SwiftUI Migration

Working document for the ongoing migration of Scritch's UI from AppKit (XIB + storyboard +
`NSViewController`) to SwiftUI. Written so that an agent or human with no prior context can pick
this up mid-flight.

**Branch:** `swiftui-migration` (off `main`)
**Started:** 2026-07-27
**Status:** Phases 0–3 complete and verified. UI test suite in progress. Phase 4 not started.

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
  pbxproj group**, yet their tests execute (23 pass). Don't be confused by this when editing that
  target.
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
  Object ID convention in use: `FA0000000000000000000C..`. Allocated so far: `C0x`–`C8x`.
  **Next free prefix: `C9x`.** Verify edits with `plutil -lint`.
- **Verify XIB edits parse** after any hand-editing:
  `python3 -c "import xml.dom.minidom;xml.dom.minidom.parse('Scritch/UI/Base.lproj/MainMenu.xib');print('OK')"`

---

## Architecture: the bridging pattern

Because the app is still `@NSApplicationMain` with `MainMenu.xib`, SwiftUI views are embedded into
the AppKit hierarchy via `NSHostingView`. Each converted area follows the same shape:

> An `ObservableObject` model owns the state and behaviour. AppKit code writes to the model; the
> SwiftUI view observes it. Consumers hold a **settable** `var model: Model = .shared` so Phase 4
> can swap in `@Environment` injection without touching call sites.

Models introduced so far, all in `Scritch/Scritch/System/`:

| Model | Owns | Bridges |
|---|---|---|
| `StatusStore` | `Status` enum, message queue, 10s display timing | `ScriptManager`, `UpdateBuddy`, `PopoverViewController` → `StatusBarView` |
| `EditorLanguageModel` | current language, auto/manual mode, `displayName(for:)` | `CodeEditorView` → `LanguageStatusBarView` |
| `ScriptPickerModel` | `isPresented`, query, results, selection, focus, list height | `PopoverViewController` → `ScriptPickerView` |

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

---

## Current state

- XIB: 750 → **538 lines**
- Remaining AppKit interface-builder wiring: **23** `@IBOutlet`/`@IBAction`/`@NSApplicationMain`
  references across 4 files — `AppDelegate.swift`, `MainViewController.swift`,
  `PopoverViewController.swift`, `SettingsWindowController.swift`.

---

## Task list

| # | Phase | Status |
|---|---|---|
| 0 | Decouple system layer from `StatusView` | ✅ done (`644b60a`) |
| 1 | Preferences → SwiftUI | ✅ done (`d7b9ac0`) |
| 2 | Status bars → SwiftUI | ✅ done (`f7983fb`) |
| 3 | Script picker popover → SwiftUI | ✅ done (`1c5f1cc`) |
| — | **XCUITest suite** (regression oracle for Phase 4) | ✅ done (`b4c8acb`) |
| 4 | SwiftUI app shell, `.commands`, `SourceEditor` | ⏳ next |

**Phase 4 workflow:** run the full suite green *before* starting, then again after. Any test that
goes red is either a real regression or a broken identifier — investigate, never weaken the test.

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
| `settings.tab.scripts`, `settings.tab.colors` | Preferences tabs | |
| `settings.colorSchemePicker` | Preferences colour-scheme picker | |

Menu titles "Open Picker" / "Close Picker" / "Scripts" are treated as stable user-visible text
rather than identifiers.

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

### Next: Phase 4 — the app shell

The dangerous phase. Scope:

1. Replace `@NSApplicationMain` + `AppDelegate` with a SwiftUI `@main App` struct and a `Window`
   scene. `AppDelegate` survives via `NSApplicationDelegateAdaptor` for the services provider
   (`textServiceHandler`) and window frame autosave (`scritch.app.window`).
2. Replace `MainMenu.xib`'s menus with `.commands`. Note `AppDelegate.setPopover(isOpen:)` currently
   swaps the visibility of the Open/Close Picker menu items — that needs a SwiftUI equivalent.
3. Replace `SettingsWindowController` with a real `Settings` scene and delete
   `showPreferencesWindow`.
4. Delete the `StatusView` hosting shim and use `StatusBarView` directly in a `.toolbar`.
5. Replace the `CodeEditorView` facade (264 lines) with the package's SwiftUI `SourceEditor`.
6. `EditorLanguageModel` moves into the SwiftUI environment; the constraint surgery in
   `MainViewController.setUpLanguageStatusBar()` disappears entirely.

**The one hard problem.** `ScriptManager.replaceText` calls `editor.replace(ranges:with:)`, which
walks ranges back-to-front inside a single undo group via `textView.replaceCharacters`. A
`Binding<String>` cannot express that — round-tripping the whole document through a String binding
would collapse undo and break multi-cursor scripts.

`SourceEditor` (CodeEditSourceEditor 0.15.2) offers two initialisers: one taking
`Binding<String>`, one taking an `NSTextStorage`. **Use the `NSTextStorage` variant** and keep a
`TextViewCoordinator` handle for ranged mutation. Decide this before starting, not during.
Selections are available via `SourceEditorState.cursorPositions`, whose `CursorPosition` exposes
`.range` — that covers what `ScriptManager` reads.

---

## Deferred / out of scope

- Fixing the `Scritch (App Store)` target's `Rearrange` module failure.
- Adding the two orphaned unit test files to the pbxproj group.
- `StatusView.fadeText(to:completionHandler:)` was dead code and was removed in Phase 2.
