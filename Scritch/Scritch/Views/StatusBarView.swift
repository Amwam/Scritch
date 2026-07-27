//
//  StatusBarView.swift
//  Scritch
//
//  SwiftUI rendering of the toolbar status pill. Purely a renderer: all state
//  and timing lives in `StatusStore`. Hosted inside the XIB's toolbar item by
//  `StatusView`, which is now nothing more than an `NSHostingView` container.
//

import SwiftUI

struct StatusBarView: View {

    @ObservedObject var store: StatusStore

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)

            Text(message)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(Color(nsColor: .headerTextColor))
                .accessibilityIdentifier("statusBar.message")

            if let link = updateLink {
                LearnMoreLink(link: link)
            }

            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 200, height: 20)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(backgroundPair.color(for: colorScheme))
        )
    }

    /// The text shown in the pill for the current status.
    private var message: String {
        switch store.current {
        case .help(let value), .info(let value), .error(let value), .success(let value):
            return value
        case .normal:
            return "Press ⌘+B to get started"
        case .updateAvailable:
            return "New version available!"
        }
    }

    /// Non-nil only while an update is being advertised.
    private var updateLink: String? {
        if case .updateAvailable(let link) = store.current {
            return link
        }
        return nil
    }

    /// Pill background, matching the colours the AppKit view used.
    private var backgroundPair: ColorPair {
        switch store.current {
        case .normal, .help:
            return ColorPair.normal
        case .success:
            return ColorPair.green.swap
        case .info:
            return ColorPair.blue.swap
        case .error:
            return ColorPair.red.swap
        case .updateAvailable:
            return ColorPair.purple
        }
    }
}

/// The underlined "Learn More" affordance that replaces `UpdateTextField`.
private struct LearnMoreLink: View {

    let link: String

    var body: some View {
        Button {
            guard let url = URL(string: link) else { return }
            NSWorkspace.shared.open(url)
        } label: {
            Text("Learn More")
                .font(.system(size: 11, weight: .medium))
                .underline()
                .foregroundColor(Color(nsColor: .labelColor))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension ColorPair {
    /// SwiftUI flavour of `value(for:)`, keyed off the environment colour scheme
    /// rather than an `NSAppearance`.
    func color(for scheme: ColorScheme) -> Color {
        Color(nsColor: scheme == .dark ? dark : light)
    }
}
