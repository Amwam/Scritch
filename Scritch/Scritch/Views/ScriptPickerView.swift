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
        .onChange(of: model.focus) { _, newValue in
            if focus != newValue { focus = newValue }
        }
        .onChange(of: focus) { _, newValue in
            if model.focus != newValue { model.focus = newValue }
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
            .modifier(PickerKeyHandlers(model: model))
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
        .modifier(PickerKeyHandlers(model: model))
    }
}

// MARK: - Keyboard

/// Every key the picker cares about. Applied to both focusable areas (the
/// search field and the list) so that whichever one owns the keyboard sees the
/// event first and can swallow it — returning `.handled` is what stops AppKit
/// playing the "funk" alert sound.
private struct PickerKeyHandlers: ViewModifier {

    @ObservedObject var model: ScriptPickerModel

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
                model.moveSelection(by: press.modifiers.contains(.shift) ? -1 : 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                if model.focus == .search {
                    guard !model.results.isEmpty else { return .ignored }
                    model.focusList()
                } else {
                    model.moveSelection(by: 1)
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard model.focus == .list else { return .ignored }
                if (model.selection ?? 0) <= 0 {
                    model.focusSearch()
                } else {
                    model.moveSelection(by: -1)
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
