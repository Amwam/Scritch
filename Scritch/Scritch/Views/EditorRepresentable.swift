//
//  EditorRepresentable.swift
//  Scritch
//
//  Thin SwiftUI wrapper around `CodeEditorView`. The editor instance is owned
//  by `AppModel` for the app's lifetime — this must not create its own, or
//  every SwiftUI rebuild would drop the document, undo stack and language state.
//

import SwiftUI

struct EditorRepresentable: NSViewRepresentable {
    let editor: CodeEditorView

    func makeNSView(context: Context) -> CodeEditorView { editor }
    func updateNSView(_ nsView: CodeEditorView, context: Context) {}
}
