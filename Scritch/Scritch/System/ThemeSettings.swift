//
//  ThemeSettings.swift
//  Scritch
//
//  Application colour scheme preference.
//

import Cocoa
import Foundation

/// The user selectable colour scheme for the app.
///
/// The raw values are persisted (as an `Int`) under
/// `ScritchColorScheme.userPreferencesSchemeKey` and must not be reordered:
/// existing users already have these values stored on disk.
enum ScritchColorScheme: Int, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let userPreferencesSchemeKey = "scritchColorScheme"

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: return "Same as System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    /// The currently stored colour scheme, defaulting to `.system`.
    static var current: ScritchColorScheme {
        ScritchColorScheme(
            rawValue: UserDefaults.standard.integer(forKey: userPreferencesSchemeKey)
        ) ?? .system
    }

    /// Applies the stored colour scheme to the running application.
    static func applyTheme() {
        NSApp.appearance = current.appearance
    }
}
