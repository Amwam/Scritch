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
            self?.hidePicker()
        }
        pickerModel.onRun = { [weak self] script in
            guard let self = self else { return }
            // Dismiss first, then run, in case the script needs to show a status.
            self.hidePicker()
            self.scriptManager.runScript(script, into: self.editor)
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

    func hidePicker() {
        guard pickerModel.isPresented else { return }

        pickerModel.isPresented = false
        pickerModel.requestFocus(nil)
        pickerModel.reset()

        statusStore.setStatus(.normal)
        isPickerOpen = false

        editor.window?.makeFirstResponder(editor.textView)
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
