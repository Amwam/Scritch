//
//  ScriptPickerModel.swift
//  Scritch
//
//  The single source of truth for the script picker popover, in the same spirit
//  as `StatusStore` and `EditorLanguageModel`. It owns presentation, the query,
//  the results and the highlighted row; `ScriptPickerView` renders it and
//  `AppModel` wires it to `ScriptManager` / the editor.
//

import AppKit
import Combine

final class ScriptPickerModel: ObservableObject {

    /// The two things inside the popover that can own the keyboard.
    enum Field: Hashable {
        case search
        case list
    }

    /// Height of a single result row, matching the old table view.
    static let rowHeight: CGFloat = 45
    /// Vertical padding added around the list once there is at least one result.
    static let listPadding: CGFloat = 20
    /// Number of rows visible before the list starts scrolling.
    static let maxVisibleRows = 5

    @Published var isPresented = false
    @Published var query = ""
    @Published private(set) var results: [Script] = []
    /// Index of the highlighted row, or `nil` when nothing is highlighted.
    @Published var selection: Int?
    /// Which field should own the keyboard. This is a one-way *request*: the
    /// view mirrors it into `@FocusState` and never writes back. The previous
    /// two-way sync wrote this from inside `onChange(of: focusState)`, which
    /// SwiftUI runs during the view update — the same "publishing from within
    /// view updates" shape the key handlers had to be moved off.
    @Published private(set) var focus: Field?

    /// Bumped by every focus request. The view observes this rather than
    /// `focus` itself, so re-requesting the field the model last requested
    /// still moves the keyboard — SwiftUI can move focus on its own (a mouse
    /// click into the search field) and the model deliberately no longer
    /// observes that, so `focus` alone can be stale.
    @Published private(set) var focusToken = 0

    /// Supplies results for a query. Wired to `ScriptManager.search(_:)`.
    var searchProvider: ((String) -> [Script])?
    /// Called when the user commits a script.
    var onRun: ((Script) -> Void)?
    /// Called when the popover should close.
    var onDismiss: (() -> Void)?

    // MARK: - Derived state

    /// The exact height the old `tableHeightConstraint` used.
    var listHeight: CGFloat {
        let rows = min(Self.maxVisibleRows, results.count)
        return Self.rowHeight * CGFloat(rows) + (results.isEmpty ? 0 : Self.listPadding)
    }

    /// The script Enter would run. With nothing highlighted this is the first
    /// result, which is what makes "type and hit Enter" work.
    var selectedScript: Script? {
        guard let selection, results.indices.contains(selection) else {
            return results.first
        }
        return results[selection]
    }

    // MARK: - Search

    func updateQuery(_ query: String) {
        guard !query.isEmpty else {
            results = []
            selection = nil
            return
        }
        results = searchProvider?(query) ?? []
        selection = nil
    }

    /// Clears the query and results without touching presentation.
    func reset() {
        query = ""
        results = []
        selection = nil
    }

    // MARK: - Selection

    /// Moves the highlight by `offset`, doing nothing if that leaves the list.
    /// With no highlight, a forward move lands on the first row — the same net
    /// effect the old table had when tabbing out of an empty selection.
    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        let next = (selection ?? -1) + offset
        guard results.indices.contains(next) else { return }
        selection = next
    }

    func select(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selection = index
    }

    /// Asks the view to move the keyboard to `field`.
    func requestFocus(_ field: Field?) {
        focus = field
        focusToken &+= 1
    }

    /// Down arrow from the search field: move into the list, on its first row.
    func focusList() {
        guard !results.isEmpty else { return }
        selection = 0
        requestFocus(.list)
    }

    /// Up arrow on the first row: go back to the search field. The old table
    /// deselected everything when it resigned first responder, so we do too.
    func focusSearch() {
        selection = nil
        requestFocus(.search)
    }

    // MARK: - Commands

    func dismiss() {
        guard isPresented else { return }
        onDismiss?()
    }

    /// Runs a specific script (double click).
    func run(_ script: Script) {
        guard isPresented else { return }
        onRun?(script)
    }

    /// Runs whatever Enter should run. Returns false when there was nothing to
    /// run, so the key press can fall through instead of being swallowed.
    @discardableResult
    func runSelected() -> Bool {
        guard isPresented, let script = selectedScript else { return false }
        onRun?(script)
        return true
    }

    // MARK: - Icons

    /// Resolves a script's icon: asset catalog first, then an SF Symbol of the
    /// same name, then the unknown placeholder. Moved here verbatim from
    /// `ScriptsTableViewController`.
    static func icon(for identifier: String?) -> NSImage? {
        guard let identifier else {
            return NSImage(named: "icons8-unknown")
        }
        if let namedImage = NSImage(named: "icons8-\(identifier)") {
            return namedImage
        }
        if let systemImage = NSImage(systemSymbolName: identifier, accessibilityDescription: nil) {
            return systemImage
        }
        return NSImage(named: "icons8-unknown")
    }
}
