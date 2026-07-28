//
//  ScriptPickerView.swift
//  Scritch
//
//  The ⌘B script picker: a full-window dimming scrim with a rounded popover on
//  top of it. Replaces OverlayView / PopoverContainerView / PopoverView /
//  SearchField / ScriptTableView(+Cell) / ScriptsTableViewController. All state
//  lives in `ScriptPickerModel`; `PopoverViewController` hosts this view inside
//  the AppKit window until the window itself becomes SwiftUI.
//

import SwiftUI

struct ScriptPickerView: View {

    @ObservedObject var model: ScriptPickerModel

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focus: ScriptPickerModel.Field?

    /// Matches the old auto layout: 440 wide, 26 down from the window top.
    private let popoverWidth: CGFloat = 440
    private let popoverTopInset: CGFloat = 26
    private let cornerRadius: CGFloat = 12

    var body: some View {
        ZStack(alignment: .top) {
            // The dimming scrim. Clicking it dismisses, as `OverlayView` did.
            Rectangle()
                .fill(ColorPair.overlayColor.color(for: colorScheme))
                .contentShape(Rectangle())
                .onTapGesture { model.dismiss() }
                .accessibilityIdentifier("picker.scrim")

            popover
                .frame(width: popoverWidth)
                .padding(.top, popoverTopInset)
        }
        .opacity(model.isPresented ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: model.isPresented)
        .allowsHitTesting(model.isPresented)
        // Escape is routed as a cancel action before it ever reaches
        // `onKeyPress`, so handle it here as well. `dismiss()` is guarded.
        .onExitCommand { model.dismiss() }
        // One-way: the model requests focus, the view obeys. There is
        // deliberately no write-back — see `ScriptPickerModel.focus`.
        .onChange(of: model.focusToken) { _, _ in
            focus = model.focus
        }
    }

    // MARK: - Popover

    private var popover: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            if !model.results.isEmpty {
                resultsList
            }
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ColorPair.popover.color(for: colorScheme))
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(ColorPair.popoverBorder.color(for: colorScheme), lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(ColorPair.popoverOutline.color(for: colorScheme), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 5, x: 0, y: 20)
    }

    private var searchField: some View {
        TextField("Start typing...", text: $model.query)
            .textFieldStyle(.plain)
            .font(.system(size: 21, weight: .light))
            .foregroundColor(Color(nsColor: .labelColor))
            .frame(height: 30)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, model.results.isEmpty ? 8 : 0)
            .focused($focus, equals: .search)
            .onChange(of: model.query) { _, newValue in
                model.updateQuery(newValue)
            }
            .modifier(PickerKeyHandlers(model: model, field: .search))
            .accessibilityIdentifier("picker.searchField")
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.results.enumerated()), id: \.offset) { index, script in
                        ScriptRow(script: script, isSelected: model.selection == index)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { model.run(script) }
                            .onTapGesture { model.select(index) }
                    }
                }
                .padding(.vertical, ScriptPickerModel.listPadding / 2)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.selection) { _, newValue in
                guard let newValue else { return }
                proxy.scrollTo(newValue, anchor: .center)
            }
        }
        .frame(height: model.listHeight)
        .focusable()
        .focusEffectDisabled()
        .focused($focus, equals: .list)
        .modifier(PickerKeyHandlers(model: model, field: .list))
        .accessibilityIdentifier("picker.resultsList")
    }
}

// MARK: - Keyboard

/// Every key the picker cares about. Applied to both focusable areas (the
/// search field and the list) so that whichever one owns the keyboard sees the
/// event first and can swallow it — returning `.handled` is what stops AppKit
/// playing the "funk" alert sound.
private struct PickerKeyHandlers: ViewModifier {

    @ObservedObject var model: ScriptPickerModel
    /// Which area these handlers are attached to. Taken as a plain value
    /// rather than read back off the model, so key handling never depends on
    /// the model's view of where focus is.
    let field: ScriptPickerModel.Field

    /// SwiftUI evaluates `onKeyPress` actions *inside the view update pass*, so
    /// publishing from one is "Publishing changes from within view updates is
    /// not allowed" — measured at 24 warnings per four arrow presses.
    ///
    /// Only the highlight/focus keys are deferred. `escape` and `return` are
    /// deliberately left synchronous: they end in `hidePicker()` +
    /// `ScriptManager.runScript`, and deferring those off the key event breaks
    /// undo — `testUndoRestoresTextAfterScriptRuns` goes red. Neither emits the
    /// warning anyway, because the picker tears down rather than re-rendering.
    private func enqueue(_ body: @escaping () -> Void) {
        DispatchQueue.main.async(execute: body)
    }

    func body(content: Content) -> some View {
        content
            .onKeyPress(.escape) {
                model.dismiss()
                return .handled
            }
            .onKeyPress(.return) {
                model.runSelected() ? .handled : .ignored
            }
            .onKeyPress(keys: [.tab]) { press in
                // Tab moves the highlight without moving focus, and is always
                // swallowed so focus can never escape back to the document.
                let offset = press.modifiers.contains(.shift) ? -1 : 1
                enqueue { model.moveSelection(by: offset) }
                return .handled
            }
            .onKeyPress(.downArrow) {
                if field == .search {
                    guard !model.results.isEmpty else { return .ignored }
                    enqueue { model.focusList() }
                } else {
                    enqueue { model.moveSelection(by: 1) }
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard field == .list else { return .ignored }
                if (model.selection ?? 0) <= 0 {
                    enqueue { model.focusSearch() }
                } else {
                    enqueue { model.moveSelection(by: -1) }
                }
                return .handled
            }
    }
}

// MARK: - Row

private struct ScriptRow: View {

    let script: Script
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            if let image = ScriptPickerModel.icon(for: script.icon) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
            } else {
                Color.clear.frame(width: 30, height: 30)
            }

            VStack(alignment: .leading, spacing: -2) {
                Text(script.name ?? "No Name 🤔")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(titleColor)
                Text(script.desc ?? "No Description 😢")
                    .font(.system(size: NSFont.smallSystemFontSize))
                    .foregroundColor(subtitleColor)
            }
            .lineLimit(1)
            .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .frame(height: ScriptPickerModel.rowHeight)
        .background(
            isSelected
                ? Color(nsColor: .selectedContentBackgroundColor)
                : Color.clear
        )
        // Stable per-row identifier keyed off the script's own name, e.g.
        // "picker.row.Base64 Encode". Phase 4 must keep script names as the key.
        .accessibilityIdentifier("picker.row.\(script.name ?? "")")
        // Exposes highlight state for UI tests without depending on script
        // ordering (which is not guaranteed stable): a test can look for
        // whichever row currently reports "selected" rather than assuming
        // a specific script occupies a specific index.
        .accessibilityValue(isSelected ? "selected" : "")
    }

    private var titleColor: Color {
        isSelected ? Color(nsColor: .alternateSelectedControlTextColor)
                   : Color(nsColor: .controlTextColor)
    }

    private var subtitleColor: Color {
        isSelected ? Color(nsColor: .alternateSelectedControlTextColor).opacity(0.75)
                   : Color(nsColor: .tertiaryLabelColor)
    }
}

private extension ColorPair {
    /// SwiftUI flavour of `value(for:)`, keyed off the environment colour scheme.
    func color(for scheme: ColorScheme) -> Color {
        Color(nsColor: scheme == .dark ? dark : light)
    }
}
