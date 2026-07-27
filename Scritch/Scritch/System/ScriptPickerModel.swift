//
//  ScriptPickerModel.swift
//  Scritch
//
//  The single source of truth for the script picker popover, in the same spirit
//  as `StatusStore` and `EditorLanguageModel`. It owns presentation, the query,
//  the results and the highlighted row; `ScriptPickerView` renders it and
//  `PopoverViewController` wires it to `ScriptManager` / the editor.
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
    /// Which field should own the keyboard. Mirrored into `@FocusState`.
    @Published var focus: Field?

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

    /// Down arrow from the search field: move into the list, on its first row.
    func focusList() {
        guard !results.isEmpty else { return }
        selection = 0
        focus = .list
    }

    /// Up arrow on the first row: go back to the search field. The old table
    /// deselected everything when it resigned first responder, so we do too.
    func focusSearch() {
        selection = nil
        focus = .search
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
