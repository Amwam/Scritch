//
//  UITestSupport.swift
//  ScritchUITests
//
//  Shared launch/query helpers for the whole suite.
//
//  ACCESSIBILITY IDENTIFIER VOCABULARY
//  ------------------------------------
//  These are the stable, user-behaviour-level identifiers the suite queries.
//  Phase 4 (and any future rewrite) MUST keep every one of these working,
//  wherever the underlying view type ends up living:
//
//    editor.textView            - the document editor's text view (role .textArea)
//    picker.scrim                - the ⌘B popover's dimming background
//    picker.searchField          - the ⌘B popover's search text field
//    picker.resultsList           - the ⌘B popover's scrollable results list
//    picker.row.<Script Name>    - one row per script, keyed by its exact
//                                  `Script.name` (e.g. "picker.row.Base64 Encode").
//                                  Also carries an accessibility *value* of
//                                  "selected" while highlighted, and "" otherwise -
//                                  tests use this instead of assuming row order,
//                                  because script load order is not guaranteed.
//    statusBar.message            - the toolbar status pill's text
//    languageBar.picker           - the bottom language bar's menu button; its
//                                  label/title is the human-readable status
//                                  ("Auto", "Auto · Bash", "Python", ...)
//    settings.tab.scripts         - Preferences window's "Scripts" tab control
//    settings.tab.colors          - Preferences window's "Colors" tab control
//    settings.colorSchemePicker   - Preferences window's colour scheme picker
//
//  Menu item titles are also load-bearing and treated as stable, user-visible
//  text (not identifiers): "Open Picker", "Close Picker", "Scripts" (menu).
//
import XCTest

extension XCTestCase {

    /// Launches a fresh instance of the app with a hermetic starting state:
    /// `UITEST_RESET_STATE=1` tells `AppDelegate` to wipe the couple of
    /// `UserDefaults` a test could otherwise leak between runs (persisted
    /// language override, persisted colour scheme). See `AppDelegate.swift`.
    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET_STATE"] = "1"
        app.launch()
        return app
    }
}

extension XCUIApplication {

    /// Looks up an element by accessibility identifier without committing to
    /// a specific `XCUIElementType` — deliberately, since Phase 4 may change
    /// which concrete AppKit/SwiftUI type backs any of these identifiers.
    func el(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }

    var editorTextView: XCUIElement { el("editor.textView") }
    var pickerSearchField: XCUIElement { el("picker.searchField") }
    var pickerResultsList: XCUIElement { el("picker.resultsList") }
    var pickerScrim: XCUIElement { el("picker.scrim") }
    var statusBarMessage: XCUIElement { el("statusBar.message") }
    var languageBarPicker: XCUIElement { el("languageBar.picker") }

    func pickerRow(named name: String) -> XCUIElement { el("picker.row.\(name)") }

    /// The currently highlighted row in the picker's results list, if any.
    /// Looks at the "selected" accessibility *value* rather than assuming a
    /// specific script occupies a specific index (load order isn't guaranteed).
    var highlightedPickerRow: XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'picker.row.' AND value == 'selected'"))
            .firstMatch
    }

    // MARK: - High-level actions

    /// Clicks the editor and replaces its full contents via select-all + type.
    func setEditorText(_ text: String) {
        editorTextView.click()
        typeKey("a", modifierFlags: .command)
        if !text.isEmpty {
            editorTextView.typeText(text)
        } else {
            typeKey(.delete, modifierFlags: [])
        }
    }

    /// Opens the ⌘B picker and waits for the search field to be ready.
    @discardableResult
    func openPicker(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        typeKey("b", modifierFlags: .command)
        let field = pickerSearchField
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Picker search field never appeared", file: file, line: line)
        return field
    }

    /// Opens the picker, searches for `query`, waits for `resultName` to
    /// appear among the results, then presses Return to run whichever script
    /// Enter would run (the first result, unless something is highlighted).
    func runScript(query: String, resultName: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = openPicker(file: file, line: line)
        field.click()
        field.typeText(query)
        XCTAssertTrue(
            pickerRow(named: resultName).waitForExistence(timeout: 5),
            "Expected result '\(resultName)' never appeared for query '\(query)'",
            file: file, line: line
        )
        field.typeText("\r")
    }
}
