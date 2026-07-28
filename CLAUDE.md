# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Scritch is a macOS app: a scriptable scratchpad where you paste text and run JavaScript
transformations over it. It is a fork of [Boop](https://github.com/IvanMathy/Boop) — most of the code
and all of the design originate there, and Boop script compatibility is a deliberate constraint.

The git repo directory is still named `Boop/`, but everything inside was renamed to Scritch. The
Xcode project is `Scritch/Scritch.xcodeproj` (target/scheme `Scritch`, tests `ScritchTests` and
`ScritchUITests`, bundle id `me.amwam.Scritch`). Deployment target macOS 14, Swift 5.

The UI was migrated from AppKit (XIB + storyboard + view controllers) to SwiftUI in July 2026. The
XIB and storyboard are gone; comments across the codebase still narrate that migration in terms of
"Phase N" and of the AppKit objects they replaced.

## Build & test

Headless `xcodebuild` needs two extra things beyond the obvious invocation:

- `-skipPackagePluginValidation` — CodeEditSourceEditor pulls in a SwiftLint build-tool plugin that
  otherwise fails validation in non-interactive builds.
- `-clonedSourcePackagesDirPath <dir>` — the default DerivedData `SourcePackages` intermittently
  corrupts SwiftTreeSitter's grammar submodules ("already exists in file system"). A dedicated,
  stable cache dir avoids it.

```bash
cd Scritch

# Build
xcodebuild -project Scritch.xcodeproj -scheme Scritch -configuration Debug \
  -destination 'platform=macOS' -clonedSourcePackagesDirPath /tmp/scritch-spm \
  -skipPackagePluginValidation build

# All tests (unit + UI)
xcodebuild -project Scritch.xcodeproj -scheme Scritch -configuration Debug \
  -destination 'platform=macOS' -clonedSourcePackagesDirPath /tmp/scritch-spm \
  -skipPackagePluginValidation test

# Unit tests only (36, <1s). The 17 UI tests launch the real app and take ~2 min.
... -only-testing:ScritchTests test

# One test / class
... -only-testing:ScritchTests/LanguageDetectorTests/testGo test
```

Both commands end with `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **` followed by
`Running SwiftLint for CodeEditTextView/CodeEditSourceEditor ... (2 failures)`. Those two are the
sandboxed lint plugin for the *dependencies* and are non-fatal — check the SUCCEEDED line, not the
exit tail.

Dependencies are SPM: CodeEditSourceEditor (editor), CodeEditLanguages (tree-sitter grammars),
and IvanMathy/fuse-swift (fuzzy search).

## Architecture

### App shell: SwiftUI scenes over an AppModel coordinator

`ScritchApp.swift` is the `@main` entry point: one `Window` scene (`ContentView`) plus a `Settings`
scene (`SettingsView`, i.e. ⌘,). `AppDelegate` survives only through
`@NSApplicationDelegateAdaptor`, for the few things scenes don't cover — the Services provider,
`ScritchColorScheme.applyTheme()`, and the UI-test state reset.

`System/AppModel.swift` is the coordinator that replaced the XIB's object graph and the old view
controllers. It owns `ScriptManager`, `UpdateBuddy`, the single `CodeEditorView`, and the three
`ObservableObject` state models, and wires them together in its `init`. It's a `@StateObject` on the
scene *and* an `AppModel.shared` singleton, because `AppDelegate`'s services handler has no route to
the SwiftUI environment.

State models, each owning one piece of UI state so the system layer never touches a view:

- `StatusStore` — the toolbar status pill's state, its queue, and the 10s message timing. Statuses
  `.normal` / `.help` / `.updateAvailable` skip and clear the queue; everything else queues.
- `ScriptPickerModel` — the ⌘B popover: presentation, query, results, highlighted row, focus.
- `EditorLanguageModel` — bridges the AppKit editor and the SwiftUI language bar.

Menus live in `ScritchCommands.swift` (SwiftUI `Commands`), not in a menu XIB.

Two SwiftUI hazards are already worked around here; preserve the shape:

- **Publishing from within view updates.** The picker's key handlers run inside SwiftUI's view
  update, so `AppModel`'s `onDismiss`/`onRun` defer the publishing teardown with
  `DispatchQueue.main.async`.
- **Undo.** The script run itself must *not* be deferred: `CodeEditorView.replace` groups through
  `textView.undoManager`, which resolves along the responder chain, so focus is returned to the text
  view and the edit happens inside the key event. Deferring it makes ⌘Z silently do nothing.

### Editor: an AppKit facade inside SwiftUI

`Editor/CodeEditorView.swift` is an `NSView` facade hosting CodeEditSourceEditor's
`TextViewController` and exposing a Scritch-shaped API (`text`, `selectedRanges`,
`replace(ranges:with:)`, `overrideLanguage`, `resetToAutoLanguage`, `applyTheme`, `onLanguageChange`).
Everything downstream talks to the facade, never to CodeEdit directly. `editor.textView` is a
`CodeEditTextView.TextView`, **not** an `NSTextView` — AppKit text APIs mostly don't apply.

`Views/EditorRepresentable.swift` is an `NSViewRepresentable` that returns the instance `AppModel`
owns. It must not construct its own: a new editor per SwiftUI rebuild would drop the document, undo
stack and language state.

`replace(ranges:with:)` applies replacements back-to-front inside one undo group, so callers pass
original (un-offset) ranges.

### Script execution pipeline

1. `ScriptManager` loads scripts at init and on `⇧⌘R`: bundled ones from the app bundle's `scripts/`
   subdirectory, user ones from the folder the user picked in Preferences.
2. Each `.js` file must begin with a `/** { ...json... } **/` metadata header (`name`, `description`,
   `icon`, `tags`, optional `bias`). Loading is best-effort — a malformed header means the script is
   silently skipped with a `print` to the console.
3. `Script` lazily builds one `JSContext` per script and evaluates the file once; the context (and any
   globals) stays alive for the app's lifetime. `main(state)` is re-invoked per run.
4. `ScriptExecution` is the JS-visible bridge (`@objc` + `JSExport`) carrying `text` / `fullText` /
   `selection` / `insert()` / `postInfo()` / `postError()`. Properties are dynamic getters/setters
   into Swift, so scripts should read them once into locals.
5. `ScriptManager.runScript(_:into:)` implements the selection semantics: no selection → run once over
   the whole document; N selections → run `main()` N times, once per range. Ranges are `NSRange`s over
   `NSString` for unicode safety.

`Script+Require.swift` implements `require()`: `@scritch/x` and the legacy `@boop/x` both resolve to
`scripts/lib/x.js` in the bundle; any other path resolves relative to the user's scripts folder and is
only allowed for user scripts (built-ins can't require user files). Modules are text-wrapped in a
CommonJS-ish IIFE — not real CommonJS.

### Two script directories

- `Scritch/Scritch/scripts/` — shipped with the app. It is a **folder reference** in the pbxproj, so
  adding a `.js` there needs no project-file edit. `scripts/lib/` holds the vendored `@scritch/`
  modules (marked `linguist-vendored`).
- `/Scripts/` at the repo root — the community/extras collection, *not* bundled; users download these
  into their own scripts folder.

### Search

`ScriptManager.search` uses Fuse over `name` (0.9), `tags` (0.6), `desc` (0.2), drops results scoring
worse than 0.4, and subtracts each script's `bias`. `*` returns everything alphabetically; queries of
20+ characters return nothing (a paste into the search box used to crash Fuse).

### Language detection & theming

`Editor/LanguageDetector.swift` guesses the language from content alone (there are no filenames): it
scans a 2 KB prefix, short-circuits on structural markers (shebang, `<?php`, parseable JSON, doctype),
otherwise scores keyword signatures and falls back to `.default` below a confidence threshold. It runs
debounced (150 ms) on a background queue from the facade's text-change hook. `LanguageMode` is `.auto`
or `.manual(...)`, persisted in `UserDefaults` under `editorLanguageMode` and surfaced/overridable via
`LanguageStatusBarView` at the bottom of the window. `LanguageDetectorTests` is the main unit suite —
add cases there when touching the heuristics.

Theming: `Editor/Themes/Colors.swift` defines the palette as light/dark `ColorPair`s;
`ScritchEditorTheme.theme(for: NSAppearance)` maps them into a CodeEdit `EditorTheme`. App appearance
is forced by `ScritchColorScheme.applyTheme()` (`System/ThemeSettings.swift`) from the
`scritchColorScheme` preference, whose raw `Int` values are persisted and must not be reordered.

### Sandbox

The app is sandboxed and cannot read arbitrary paths. Access to the user's scripts folder is via a
security-scoped bookmark stored in `UserDefaults` (`ScriptManager.setBookmarkData` /
`getBookmarkURL`). Anything touching user script files must go through those.

`UpdateBuddy` is deliberately inert (`updateFeed` is `nil`) — Scritch has no release feed, and pointing
it at Boop's would report upstream releases as ours. The app makes no network requests today.

### UI tests are a contract on identifiers and menu titles

`ScritchUITests/UITestSupport.swift` documents an accessibility-identifier vocabulary
(`editor.textView`, `picker.searchField`, `picker.row.<Script Name>`, `statusBar.message`,
`languageBar.picker`, `settings.colorSchemePicker`, …) that the suite queries by. Menu item titles
("Open Picker", "Close Picker", the "Scripts" menu) and the Preferences tab titles ("Scripts",
"Colors") are equally load-bearing. Changing any of them means updating the suite deliberately, not
by accident.

Tests launch the app with `UITEST_RESET_STATE=1`, which makes `AppDelegate` wipe the defaults a run
could otherwise leak into the next one (persisted language override, colour scheme, SwiftUI's
remembered Settings tab).

## Conventions

- Keep scripts Boop-compatible: the `@boop/` require prefix must keep resolving, and new scripts should
  work unmodified in upstream Boop.
- Prefer `@scritch/` in newly written scripts and docs.
- Scripts run in JavaScriptCore, not Node or a browser: no `window`, `process`, `Crypto`, no npm.
- `#if APPSTORE` gates the "Check For Updates" menu item; no build configuration currently defines it.
- `ScritchApp.swift` points at a `MIGRATION.md` for the migration rationale — that file is not in the
  repo. Don't go looking for it.
- User-facing docs live in `Scritch/Documentation/` — `CustomScripts.md` is the script-authoring
  contract and should be updated alongside changes to `ScriptExecution` or `require`.
