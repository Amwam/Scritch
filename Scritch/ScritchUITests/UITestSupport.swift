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
//                                  accessibility *value* (not label — macOS
//                                  doesn't reliably expose a Menu's title as
//                                  `label` to XCUITest) is the human-readable
//                                  status ("Auto", "Auto · Bash", "Python", ...)
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

extension XCTestCase {

    /// Waits for `element`'s visible text to equal `text`. Checked against both
    /// `label` and `value` because macOS exposes plain `Text` content via the
    /// AX *value* attribute (not *label*/title) for some element roles — using
    /// only one or the other flakes depending on exactly what backs the view.
    @discardableResult
    func waitForText(_ text: String, in element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label == %@ OR value == %@", text, text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Same as `waitForText`, but a substring match — for labels like "Auto · Bash".
    @discardableResult
    func waitForTextContaining(_ text: String, in element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Polls `condition` until it's true or `timeout` elapses, using an
    /// `NSPredicate` block expectation so XCTest's own synchronization/polling
    /// drives it — a hand-rolled `RunLoop.run(until:)` spin loop was observed
    /// to sometimes evaluate a stale accessibility snapshot instead of
    /// re-querying live UI state.
    @discardableResult
    func waitUntil(timeout: TimeInterval = 5, condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: NSObject())
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

extension XCUIApplication {

    /// Looks up an element by accessibility identifier without committing to
    /// a specific `XCUIElementType` — deliberately, since Phase 4 may change
    /// which concrete AppKit/SwiftUI type backs any of these identifiers.
    ///
    /// Uses `.firstMatch` rather than the query's string subscript: SwiftUI
    /// sometimes attaches the same identifier to more than one accessibility
    /// node for a single view (e.g. a container and a transient duplicate
    /// during a list re-render), and the subscript form hard-fails as soon as
    /// a query is ambiguous rather than just picking one.
    func el(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
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
