//
//  SettingsWindowController.swift
//  Scritch
//
//  Hosts the SwiftUI `SettingsView` in a plain AppKit window.
//
//  The app is still `@NSApplicationMain` with an AppKit `AppDelegate`, so the
//  SwiftUI `Settings` scene is not available to us yet. Once the app gains a
//  SwiftUI `App` struct this whole file can be replaced by a `Settings` scene.
//

import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {

    /// Single shared window, so re-opening Preferences focuses the existing
    /// window rather than spawning duplicates.
    static let shared: SettingsWindowController = {
        let hostingController = NSHostingController(rootView: SettingsView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(hostingController.view.fittingSize)
        window.center()

        return SettingsWindowController(window: window)
    }()

    func show(_ sender: Any?) {
        showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
