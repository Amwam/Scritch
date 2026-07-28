//
//  AppModel.swift
//  Scritch
//
//  The coordinator that replaces the object graph the XIB used to instantiate
//  and wire: `MainViewController` + `PopoverViewController` + the AppDelegate's
//  outlets. `ScritchApp` owns this as a `@StateObject`; `AppDelegate` also reaches
//  it via `.shared` because the services provider handler predates SwiftUI's
//  environment and has no other way in.
//

import AppKit
import Combine

final class AppModel: ObservableObject {

    /// XIB-instantiated code (nothing left, post Phase 4) and the AppKit
    /// services handler both need a way in that isn't SwiftUI's environment.
    static let shared = AppModel()

    let scriptManager = ScriptManager()
    let statusStore = StatusStore.shared
    let pickerModel = ScriptPickerModel()
    let languageModel = EditorLanguageModel()
    let updateBuddy = UpdateBuddy()

    /// The one editor instance for the app's lifetime. `EditorRepresentable`
    /// hands this exact instance to SwiftUI rather than constructing its own,
    /// so state (text, language, undo stack) survives view rebuilds.
    let editor = CodeEditorView(frame: .zero)

    /// Mirrors `ScriptPickerModel.isPresented` for `ScritchCommands`, which
    /// needs to swap "Open Picker" / "Close Picker" the way
    /// `AppDelegate.setPopover(isOpen:)` used to.
    @Published private(set) var isPickerOpen = false

    /// Wires the models together the way `PopoverViewController.viewDidLoad`
    /// and `MainViewController.setUpLanguageStatusBar` used to.
    private init() {
        pickerModel.searchProvider = { [weak self] query in
            self?.scriptManager.search(query) ?? []
        }
        pickerModel.onDismiss = { [weak self] in
            // Both callbacks are reached from `onKeyPress`, which SwiftUI runs
            // inside the view update — publishing there is "Publishing changes
            // from within view updates is not allowed". The teardown publishes
            // heavily, so it goes on the next run-loop turn.
            DispatchQueue.main.async { self?.hidePicker() }
        }
        pickerModel.onRun = { [weak self] script in
            guard let self = self else { return }
            // The script itself must NOT be deferred. `CodeEditorView.replace`
            // groups through `textView.undoManager`, which resolves along the
            // responder chain — so focus has to be back on the text view and
            // the edit has to happen inside the key event, or the replacement
            // lands with nothing registered to undo and ⌘Z silently does
            // nothing (`testUndoRestoresTextAfterScriptRuns`).
            self.editor.window?.makeFirstResponder(self.editor.textView)
            self.scriptManager.runScript(script, into: self.editor)
            // Only the publishing part defers. It deliberately skips the status
            // reset that `hidePicker()` does: `ScriptManager.runScript` already
            // sets `.normal` before running, so resetting here on a later turn
            // would clobber whatever status the script set.
            DispatchQueue.main.async { self.dismissPickerState() }
        }

        languageModel.onSelectLanguage = { [weak self] language in
            self?.editor.overrideLanguage(language)
        }
        languageModel.onSelectAuto = { [weak self] in
            self?.editor.resetToAutoLanguage()
        }
        editor.onLanguageChange = { [weak self] language, isAuto in
            self?.languageModel.update(language: language, isAuto: isAuto)
        }

        // Seed the bar with the editor's current state.
        languageModel.update(language: editor.currentLanguage, isAuto: editor.isAutoLanguage)
    }

    // MARK: - Picker

    func showPicker() {
        guard !pickerModel.isPresented else { return }

        pickerModel.reset()
        pickerModel.isPresented = true
        isPickerOpen = true

        // FIXME: Use localized strings
        statusStore.setStatus(.help("Select your action"))

        // Give SwiftUI a turn of the run loop to install the text field before
        // asking it for the keyboard.
        DispatchQueue.main.async { [weak self] in
            self?.pickerModel.requestFocus(.search)
        }
    }

    /// Tears down the picker's own state and returns the keyboard to the
    /// editor, without touching the status. Split out of `hidePicker()` so the
    /// run path can defer it without clobbering the script's status.
    func dismissPickerState() {
        guard pickerModel.isPresented else { return }

        pickerModel.isPresented = false
        pickerModel.requestFocus(nil)
        pickerModel.reset()

        isPickerOpen = false

        editor.window?.makeFirstResponder(editor.textView)
    }

    func hidePicker() {
        guard pickerModel.isPresented else { return }

        dismissPickerState()
        statusStore.setStatus(.normal)
    }

    func togglePicker() {
        if pickerModel.isPresented {
            hidePicker()
        } else {
            showPicker()
        }
    }

    // MARK: - Scripts

    func runScriptAgain() {
        scriptManager.runScriptAgain(editor: editor)
    }

    func reloadScripts() {
        scriptManager.reloadScripts()
    }

    // MARK: - Editor

    func clearEditor() {
        editor.text = ""
    }

    /// Used by `AppDelegate.textServiceHandler(_:userData:error:)`.
    func setEditorText(_ string: String) {
        editor.text = string
    }

    // MARK: - Updates

    func checkForUpdates() {
        updateBuddy.check()
    }

    // MARK: - Help / scripts links

    func openHelp() {
        open(url: "https://github.com/Amwam/Scritch/blob/main/Scritch/Documentation/Readme.md")
    }

    func openScripts() {
        open(url: "https://github.com/Amwam/Scritch/tree/main/Scripts")
    }

    private func open(url: String) {
        guard let url = URL(string: url) else {
            assertionFailure("Could not generate help URL.")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
