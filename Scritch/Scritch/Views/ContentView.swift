//
//  ContentView.swift
//  Scritch
//
//  The app's single window: the editor, the language bar underneath it, and
//  the ⌘B script picker overlaid on top of both. Reproduces the layout that
//  `MainMenu.xib` + `MainViewController.setUpLanguageStatusBar()` used to build
//  with Auto Layout — SwiftUI's own layout replaces that constraint surgery.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                EditorRepresentable(editor: model.editor)
                LanguageStatusBarView(model: model.languageModel)
                    .frame(height: 24)
            }

            // `ScriptPickerView` gates its own visibility/fade on
            // `model.isPresented`, so it's always in the hierarchy rather than
            // being conditionally inserted — inserting/removing it here would
            // fight its own opacity animation.
            ScriptPickerView(model: model.pickerModel)
        }
        .frame(minWidth: 480, minHeight: 320)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                StatusBarView(store: model.statusStore)
            }
        }
        .onAppear {
            // `CodeEditorView` re-applies its theme on
            // `viewDidChangeEffectiveAppearance`; this just seeds the initial
            // appearance, as `MainViewController.viewDidLoad` used to.
            model.editor.applyTheme(for: NSApp.effectiveAppearance)

            // `AppDelegate` has no environment of its own, so it reaches
            // `openWindow` through here to recreate the window after the user
            // closes it (see `AppModel.reopenWindow`).
            model.openWindow = { id in openWindow(id: id) }
        }
    }
}
