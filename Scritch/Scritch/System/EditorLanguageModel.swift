//
//  EditorLanguageModel.swift
//  Scritch
//
//  Bridge between the AppKit editor and the SwiftUI language status bar, in the
//  same spirit as `StatusStore`. The editor pushes its current language/mode in
//  through `update(language:isAuto:)`; the bar pushes user choices back out
//  through the two callbacks. When the editor itself becomes SwiftUI (a later
//  phase) only the wiring in `MainViewController` needs to change.
//

import Foundation
import CodeEditLanguages

final class EditorLanguageModel: ObservableObject {

    /// The language currently applied to the editor.
    @Published private(set) var language: CodeLanguage = .default
    /// Whether that language came from the detector rather than a user override.
    @Published private(set) var isAuto: Bool = true

    /// Called when the user picks a specific language from the menu.
    var onSelectLanguage: ((CodeLanguage) -> Void)?
    /// Called when the user picks the "Auto" entry.
    var onSelectAuto: (() -> Void)?

    /// Languages offered in the override menu, sorted by display name.
    let languages: [CodeLanguage] = CodeLanguage.allLanguages
        .sorted { displayName(for: $0) < displayName(for: $1) }

    /// Reflect the editor's current language/mode in the bar.
    func update(language: CodeLanguage, isAuto: Bool) {
        self.language = language
        self.isAuto = isAuto
    }

    func selectLanguage(_ language: CodeLanguage) {
        onSelectLanguage?(language)
    }

    func selectAuto() {
        onSelectAuto?()
    }

    /// A human-readable name for a language, since `CodeLanguage` has none.
    static func displayName(for language: CodeLanguage) -> String {
        let special: [TreeSitterLanguage: String] = [
            .cpp: "C++", .cSharp: "C#", .objc: "Objective-C",
            .css: "CSS", .html: "HTML", .json: "JSON", .jsdoc: "JSDoc",
            .sql: "SQL", .php: "PHP", .jsx: "JSX", .tsx: "TSX",
            .goMod: "Go Mod", .yaml: "YAML", .toml: "TOML", .ocaml: "OCaml",
            .ocamlInterface: "OCaml Interface", .javascript: "JavaScript",
            .typescript: "TypeScript", .plainText: "Plain Text",
            .markdownInline: "Markdown (Inline)"
        ]
        if let name = special[language.id] {
            return name
        }
        let raw = language.id.rawValue
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }
}
