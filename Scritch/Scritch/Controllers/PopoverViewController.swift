//
//  PopoverViewController.swift
//  Scritch
//
//  Created by Ivan on 1/27/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//
//  All that is left of the old AppKit picker: this hosts `ScriptPickerView`
//  inside the XIB's window and wires `ScriptPickerModel` to `ScriptManager`,
//  the editor and the app delegate. Once the window itself is SwiftUI this
//  whole class goes away.
//

import Cocoa
import SwiftUI

class PopoverViewController: NSViewController {

    @IBOutlet weak var editorView: CodeEditorView!
    @IBOutlet weak var scriptManager: ScriptManager!
    @IBOutlet weak var appDelegate: AppDelegate!

    /// Status bar state. Settable so a later phase can inject it.
    var statusStore: StatusStore = .shared

    /// The picker's state. Settable for the same reason.
    var model = ScriptPickerModel()

    private var hostingView: NSHostingView<ScriptPickerView>?

    /// How long the SwiftUI fade takes; we keep the host in the view hierarchy
    /// until it finishes, then hide it so it stops swallowing clicks.
    private static let fadeDuration = 0.2

    override func viewDidLoad() {
        super.viewDidLoad()

        model.searchProvider = { [weak self] query in
            self?.scriptManager.search(query) ?? []
        }
        model.onDismiss = { [weak self] in
            self?.hide()
        }
        model.onRun = { [weak self] script in
            guard let self = self else { return }
            // Dismiss first, then run, in case the script needs to show a status.
            self.hide()
            self.scriptManager.runScript(script, into: self.editorView)
        }

        installHostingView()
        view.isHidden = true
    }

    private func installHostingView() {
        let hosting = NSHostingView(rootView: ScriptPickerView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingView = hosting
    }

    func show() {
        guard !model.isPresented else { return }

        model.reset()
        view.isHidden = false
        model.isPresented = true

        // FIXME: Use localized strings
        statusStore.setStatus(.help("Select your action"))

        if let hostingView = hostingView {
            view.window?.makeFirstResponder(hostingView)
        }
        // Give SwiftUI a turn of the run loop to install the text field before
        // asking it for the keyboard.
        DispatchQueue.main.async { [weak self] in
            self?.model.focus = .search
        }

        appDelegate.setPopover(isOpen: true)
    }

    func hide() {
        guard model.isPresented else { return }

        model.isPresented = false
        model.focus = nil
        model.reset()

        statusStore.setStatus(.normal)

        view.window?.makeFirstResponder(editorView.textView)

        appDelegate.setPopover(isOpen: false)

        // Let the fade finish before taking the host out of the hit-test path.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeDuration) { [weak self] in
            guard let self = self, !self.model.isPresented else { return }
            self.view.isHidden = true
        }
    }

    func runScriptAgain() {
        self.scriptManager.runScriptAgain(editor: self.editorView)
    }
}
