//
//  LanguageStatusBarView.swift
//  Scritch
//
//  The thin bar along the bottom of the window showing the editor's language and
//  letting the user override the auto-detected guess. Driven entirely by
//  `EditorLanguageModel`; stacked under the editor by `ContentView`.
//

import SwiftUI
import CodeEditLanguages

struct LanguageStatusBarView: View {

    @ObservedObject var model: EditorLanguageModel

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Menu {
                Button(autoTitle) { model.selectAuto() }
                Divider()
                ForEach(model.languages, id: \.id) { language in
                    Button(EditorLanguageModel.displayName(for: language)) {
                        model.selectLanguage(language)
                    }
                }
            } label: {
                Text(currentTitle)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .font(.system(size: NSFont.smallSystemFontSize))
            .fixedSize()
            .accessibilityIdentifier("languageBar.picker")
            // `Menu`'s rendered title isn't reliably exposed through XCUITest's
            // `label`/`value` for this control role, so mirror it explicitly as
            // the accessibility value UI tests can depend on.
            .accessibilityValue(currentTitle)
        }
        .padding(.trailing, 8)
        .frame(height: 24)
    }

    /// The "Auto" entry, annotated with whatever the detector currently guesses.
    private var autoTitle: String {
        guard model.isAuto, model.language.id != CodeLanguage.default.id else {
            return "Auto"
        }
        return "Auto · \(EditorLanguageModel.displayName(for: model.language))"
    }

    /// What the collapsed menu shows: mirrors which item the pop-up used to select.
    private var currentTitle: String {
        model.isAuto ? autoTitle : EditorLanguageModel.displayName(for: model.language)
    }
}
