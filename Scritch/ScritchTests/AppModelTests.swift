//
//  AppModelTests.swift
//  ScritchTests
//
//  Unit coverage for AppModel, the coordinator that replaced
//  MainViewController + PopoverViewController in Phase 4. This is the only
//  automated check on that coordinator while the XCUITest suite can't run
//  headlessly (it needs the display).
//
//  AppModel is a singleton (`AppModel.shared`, private init), so state leaks
//  between test methods. Every test normalises its own starting state rather
//  than assuming a fresh instance.
//

import XCTest
@testable import Scritch

class AppModelTests: XCTestCase {

    let model = AppModel.shared

    override func setUp() {
        super.setUp()
        // Normalise to "picker hidden" before every test, regardless of what
        // the previous test left behind.
        model.hidePicker()
    }

    override func tearDown() {
        model.hidePicker()
        super.tearDown()
    }

    // MARK: - Show / hide state transitions

    func testShowPickerSetsPresentedAndIsPickerOpen() {
        XCTAssertFalse(model.pickerModel.isPresented)
        XCTAssertFalse(model.isPickerOpen)

        model.showPicker()

        XCTAssertTrue(model.pickerModel.isPresented)
        XCTAssertTrue(model.isPickerOpen)
    }

    func testHidePickerClearsPresentedAndIsPickerOpen() {
        model.showPicker()
        XCTAssertTrue(model.pickerModel.isPresented)
        XCTAssertTrue(model.isPickerOpen)

        model.hidePicker()

        XCTAssertFalse(model.pickerModel.isPresented)
        XCTAssertFalse(model.isPickerOpen)
    }

    // MARK: - Idempotency / guard clauses

    func testShowPickerTwiceDoesNotDoubleFire() {
        model.showPicker()
        XCTAssertTrue(model.pickerModel.isPresented)

        // Mutate query so we can tell whether a second showPicker() call
        // resets state again (it shouldn't: the guard should make it a no-op).
        model.pickerModel.query = "sentinel"

        model.showPicker()

        XCTAssertTrue(model.pickerModel.isPresented)
        XCTAssertTrue(model.isPickerOpen)
        // If the guard weren't there, showPicker() would call reset() again
        // and wipe out the query we just set.
        XCTAssertEqual(model.pickerModel.query, "sentinel")
    }

    func testHidePickerWhenAlreadyHiddenIsANoOp() {
        XCTAssertFalse(model.pickerModel.isPresented)

        // Status should be untouched by a no-op hide.
        model.statusStore.setStatus(.help("untouched"))

        model.hidePicker()

        XCTAssertFalse(model.pickerModel.isPresented)
        XCTAssertFalse(model.isPickerOpen)
        if case .help(let message) = model.statusStore.current {
            XCTAssertEqual(message, "untouched")
        } else {
            XCTFail("Expected status to remain .help(\"untouched\"), got \(model.statusStore.current)")
        }
    }

    // MARK: - togglePicker()

    func testTogglePickerFromHiddenShowsIt() {
        XCTAssertFalse(model.pickerModel.isPresented)

        model.togglePicker()

        XCTAssertTrue(model.pickerModel.isPresented)
        XCTAssertTrue(model.isPickerOpen)
    }

    func testTogglePickerFromShownHidesIt() {
        model.showPicker()
        XCTAssertTrue(model.pickerModel.isPresented)

        model.togglePicker()

        XCTAssertFalse(model.pickerModel.isPresented)
        XCTAssertFalse(model.isPickerOpen)
    }

    // MARK: - Status transitions

    func testShowPickerSetsHelpStatus() {
        model.showPicker()

        if case .help(let message) = model.statusStore.current {
            XCTAssertEqual(message, "Select your action")
        } else {
            XCTFail("Expected .help status, got \(model.statusStore.current)")
        }
    }

    func testHidePickerSetsNormalStatus() {
        model.showPicker()
        model.hidePicker()

        if case .normal = model.statusStore.current {
            // Pass
        } else {
            XCTFail("Expected .normal status, got \(model.statusStore.current)")
        }
    }

    // MARK: - Editor

    func testClearEditorEmptiesText() {
        model.setEditorText("some content")
        XCTAssertEqual(model.editor.text, "some content")

        model.clearEditor()

        XCTAssertEqual(model.editor.text, "")
    }

    func testSetEditorTextSetsEditorText() {
        // This is the path AppDelegate.textServiceHandler(_:userData:error:)
        // uses to deliver macOS Services text into the app.
        model.setEditorText("hello from services")

        XCTAssertEqual(model.editor.text, "hello from services")
    }

    // MARK: - Picker search wiring

    func testPickerSearchProviderIsWiredToScriptManagerSearch() {
        guard let searchProvider = model.pickerModel.searchProvider else {
            XCTFail("Expected pickerModel.searchProvider to be set by AppModel's init")
            return
        }

        // Built-in scripts load from the bundle in ScriptManager.init(); if the
        // unit-test host can't reach the bundle, don't assert non-empty results
        // since that's a bundle-reachability question rather than a wiring one.
        let directResults = model.scriptManager.search("base64")
        let providerResults = searchProvider("base64")

        XCTAssertEqual(
            providerResults.map(\.name),
            directResults.map(\.name),
            "pickerModel.searchProvider should delegate straight to scriptManager.search(_:)"
        )

        if !directResults.isEmpty {
            XCTAssertFalse(providerResults.isEmpty)
        }
    }

    // MARK: - hidePicker() resets picker state

    func testHidePickerClearsFocusAfterRunLoopTurn() {
        model.showPicker()

        // showPicker() sets pickerModel.focus inside DispatchQueue.main.async,
        // so let the run loop turn before asserting on it.
        let focusSetExpectation = expectation(description: "focus set to .search")
        DispatchQueue.main.async {
            focusSetExpectation.fulfill()
        }
        wait(for: [focusSetExpectation], timeout: 1)
        XCTAssertEqual(model.pickerModel.focus, .search)

        model.hidePicker()

        XCTAssertNil(model.pickerModel.focus)
    }

    func testHidePickerCallsResetClearingQueryResultsAndSelection() {
        model.showPicker()
        model.pickerModel.query = "base64"
        model.pickerModel.updateQuery("base64")
        model.pickerModel.select(0)

        model.hidePicker()

        XCTAssertEqual(model.pickerModel.query, "")
        XCTAssertTrue(model.pickerModel.results.isEmpty)
        XCTAssertNil(model.pickerModel.selection)
    }
}
