//
//  ScritchUITests.swift
//  ScritchUITests
//
//  End-to-end UI safety net for the Phase 4 SwiftUI migration. Every assertion
//  here targets user-visible text or the accessibility identifiers documented
//  in `UITestSupport.swift` — never AppKit class names or view-hierarchy shape
//  — so the suite keeps meaning after Phase 4 rewrites the implementation.
//

import XCTest

final class ScritchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - 1. Editor text entry

    func testEditorTextEntryShowsTypedText() {
        let app = launchApp()
        app.setEditorText("Hello, Scritch!")

        XCTAssertEqual(app.editorTextView.value as? String, "Hello, Scritch!")
    }

    // MARK: - 2. Script execution end-to-end (whole document, no selection)

    func testBase64EncodeRunsOnWholeDocumentWithNoSelection() {
        let app = launchApp()
        app.setEditorText("hello")

        app.runScript(query: "base64 enc", resultName: "Base64 Encode")

        // base64("hello") == "aGVsbG8="
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "aGVsbG8="),
            object: app.editorTextView
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    // MARK: - 3. Selection-scoped execution

    func testUpcaseRunsOnlyOnSelectionWhenThereIsOne() {
        let app = launchApp()
        app.setEditorText("hello world")

        // Cursor is at the end after typing; jump to the start of the document
        // and select exactly the first word ("hello") via the standard Cocoa
        // "select word right" binding, leaving " world" unselected.
        app.typeKey(.upArrow, modifierFlags: .command)
        app.typeKey(.rightArrow, modifierFlags: [.shift, .option])

        app.runScript(query: "Upcase", resultName: "Upcase")

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "HELLO world"),
            object: app.editorTextView
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    // MARK: - 4. Undo

    func testUndoRestoresTextAfterScriptRuns() {
        let app = launchApp()
        app.setEditorText("hello")

        app.runScript(query: "Upcase", resultName: "Upcase")

        let ranTolerance = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "HELLO"),
            object: app.editorTextView
        )
        XCTAssertEqual(XCTWaiter().wait(for: [ranTolerance], timeout: 5), .completed)

        app.typeKey("z", modifierFlags: .command)

        let undone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "hello"),
            object: app.editorTextView
        )
        XCTAssertEqual(XCTWaiter().wait(for: [undone], timeout: 5), .completed)
    }

    // MARK: - 5. Picker lifecycle

    func testEscDismissesPicker() {
        let app = launchApp()
        let field = app.openPicker()
        XCTAssertTrue(field.exists)

        app.typeKey(.escape, modifierFlags: [])

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    func testClickingScrimDismissesPicker() {
        let app = launchApp()
        let field = app.openPicker()
        XCTAssertTrue(field.exists)

        // Click a corner of the scrim, far from the popover itself.
        let scrim = app.pickerScrim
        XCTAssertTrue(scrim.exists)
        scrim.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.9)).click()

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    func testOpenAndClosePickerMenuItemsSwapVisibility() {
        let app = launchApp()

        app.menuBars.menuBarItems["Scripts"].click()
        XCTAssertTrue(app.menuItems["Open Picker"].exists)
        XCTAssertFalse(app.menuItems["Close Picker"].exists)
        app.menuItems["Open Picker"].click()

        XCTAssertTrue(app.pickerSearchField.waitForExistence(timeout: 5))

        app.menuBars.menuBarItems["Scripts"].click()
        XCTAssertTrue(app.menuItems["Close Picker"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.menuItems["Open Picker"].exists)
        app.menuItems["Close Picker"].click()

        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.pickerSearchField
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)

        app.menuBars.menuBarItems["Scripts"].click()
        XCTAssertTrue(app.menuItems["Open Picker"].waitForExistence(timeout: 5))
        app.menuBars.menuBarItems["Scripts"].click() // leave the menu closed
    }

    // MARK: - 6. Picker keyboard

    func testEnterWithNothingHighlightedRunsFirstResult() {
        let app = launchApp()
        app.setEditorText("hello")

        // "base64 enc" strongly favours "Base64 Encode" over "Base64 Decode",
        // so with nothing highlighted, Enter should run the encoder.
        let field = app.openPicker()
        field.click()
        field.typeText("base64 enc")
        XCTAssertTrue(app.pickerRow(named: "Base64 Encode").waitForExistence(timeout: 5))
        XCTAssertNil(app.highlightedPickerRow.value as? String) // nothing highlighted yet

        field.typeText("\r")

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "aGVsbG8="),
            object: app.editorTextView
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    func testTabAndShiftTabMoveTheHighlight() {
        let app = launchApp()
        let field = app.openPicker()
        field.click()
        field.typeText("base64") // matches both Base64 Encode and Base64 Decode

        // Wait for at least one of the two known results to appear.
        XCTAssertTrue(app.pickerRow(named: "Base64 Encode").waitForExistence(timeout: 5))
        XCTAssertTrue(app.pickerRow(named: "Base64 Decode").exists)
        XCTAssertFalse(app.highlightedPickerRow.exists, "Nothing should be highlighted yet")

        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(app.highlightedPickerRow.waitForExistence(timeout: 5))
        let firstHighlighted = app.highlightedPickerRow.identifier

        app.typeKey(.tab, modifierFlags: [])
        XCTAssertTrue(app.highlightedPickerRow.exists)
        XCTAssertNotEqual(app.highlightedPickerRow.identifier, firstHighlighted, "Tab should move the highlight")

        app.typeKey(.tab, modifierFlags: .shift)
        XCTAssertEqual(app.highlightedPickerRow.identifier, firstHighlighted, "Shift-Tab should move it back")
    }

    func testDownArrowEntersListAndUpArrowOnFirstRowReturnsToSearch() {
        let app = launchApp()
        let field = app.openPicker()
        field.click()
        field.typeText("base64")
        XCTAssertTrue(app.pickerRow(named: "Base64 Encode").waitForExistence(timeout: 5))

        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(app.highlightedPickerRow.waitForExistence(timeout: 5), "Down arrow should highlight the first row")

        app.typeKey(.upArrow, modifierFlags: [])
        let cleared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.highlightedPickerRow
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [cleared], timeout: 5), .completed,
            "Up arrow on the first row should clear the highlight and return focus to search"
        )

        // Confirm the search field really does own the keyboard again by typing more.
        field.typeText("64")
        XCTAssertTrue(app.pickerRow(named: "Base64 Encode").waitForExistence(timeout: 5))
    }

    // MARK: - 7. Search filtering

    func testSearchNarrowsToExpectedResults() {
        let app = launchApp()
        let field = app.openPicker()
        field.click()
        field.typeText("base64")

        XCTAssertTrue(app.pickerRow(named: "Base64 Encode").waitForExistence(timeout: 5))
        XCTAssertTrue(app.pickerRow(named: "Base64 Decode").exists)
        XCTAssertFalse(app.pickerRow(named: "Upcase").exists)
        XCTAssertFalse(app.pickerRow(named: "Count Characters").exists)
    }

    // MARK: - 8. Status bar

    func testStatusBarRestStateAndPickerOpenState() {
        let app = launchApp()

        XCTAssertEqual(app.statusBarMessage.label, "Press ⌘+B to get started")

        app.openPicker()
        XCTAssertEqual(app.statusBarMessage.label, "Select your action")

        app.typeKey(.escape, modifierFlags: [])
        let backToNormal = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Press ⌘+B to get started"),
            object: app.statusBarMessage
        )
        XCTAssertEqual(XCTWaiter().wait(for: [backToNormal], timeout: 5), .completed)
    }

    func testStatusBarShowsScriptOwnMessage() {
        let app = launchApp()
        app.setEditorText("hello")

        app.runScript(query: "Count Characters", resultName: "Count Characters")

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "5 characters"),
            object: app.statusBarMessage
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    // MARK: - 9. Language bar

    func testLanguageBarReflectsDetectedLanguage() {
        let app = launchApp()
        app.setEditorText("#!/bin/bash\necho hi")

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Bash"),
            object: app.languageBarPicker
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    func testOverridingLanguageAndResettingToAuto() {
        let app = launchApp()
        app.setEditorText("#!/bin/bash\necho hi")

        let detected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Bash"),
            object: app.languageBarPicker
        )
        XCTAssertEqual(XCTWaiter().wait(for: [detected], timeout: 5), .completed)

        app.languageBarPicker.click()
        app.menuItems["Python"].click()

        XCTAssertEqual(app.languageBarPicker.label, "Python")

        app.languageBarPicker.click()
        app.menuItems["Auto"].click()

        let backToAuto = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Auto"),
            object: app.languageBarPicker
        )
        XCTAssertEqual(XCTWaiter().wait(for: [backToAuto], timeout: 5), .completed)
    }

    // MARK: - 10. Preferences window

    func testPreferencesWindowTabsAndColorSchemePersistence() {
        let app = launchApp()

        app.typeKey(",", modifierFlags: .command)

        XCTAssertTrue(app.el("settings.tab.scripts").waitForExistence(timeout: 5))
        XCTAssertTrue(app.el("settings.tab.colors").exists)
        XCTAssertFalse(app.el("settings.colorSchemePicker").exists, "Colors tab shouldn't be active yet")

        app.el("settings.tab.colors").click()
        XCTAssertTrue(app.el("settings.colorSchemePicker").waitForExistence(timeout: 5))

        app.el("settings.colorSchemePicker").click()
        app.menuItems["Dark"].click()
        XCTAssertEqual(app.el("settings.colorSchemePicker").value as? String, "Dark")

        // Close and reopen the Preferences window; the AppStorage-backed
        // selection should have persisted.
        app.typeKey("w", modifierFlags: .command)
        app.typeKey(",", modifierFlags: .command)

        XCTAssertTrue(app.el("settings.tab.colors").waitForExistence(timeout: 5))
        app.el("settings.tab.colors").click()
        XCTAssertTrue(app.el("settings.colorSchemePicker").waitForExistence(timeout: 5))
        XCTAssertEqual(app.el("settings.colorSchemePicker").value as? String, "Dark")
    }
}
