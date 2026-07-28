//
//  AppDelegate.swift
//  Scritch
//
//  Created by Ivan on 1/26/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//
//  Slimmed to what `NSApplicationDelegateAdaptor` needs and `Scene`s don't
//  cover: the Services provider and window-frame autosave. Everything else
//  (menus, preferences, the picker/script actions) moved to `AppModel` and
//  `ScritchCommands` in Phase 4.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    // Frame auto save name for app window frame restoration.
    private static let appWindowName = "scritch.app.window"

    /// Resolved lazily in `applicationDidFinishLaunching`, since the XIB no
    /// longer hands us the window directly.
    private weak var mainWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        resetStateForUITestsIfRequested()

        ScritchColorScheme.applyTheme()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.servicesProvider = self

        // The `Window` scene's window exists by the time launch finishes.
        // Be defensive: this must never crash if it's somehow not found.
        let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first
        mainWindow = window
        window?.setFrameUsingName(AppDelegate.appWindowName)
    }

    /// UI tests launch the (sandboxed) app as a persistent process whose
    /// `UserDefaults` survive between test runs. To keep the suite hermetic,
    /// tests pass `UITEST_RESET_STATE=1` in `launchEnvironment`, which wipes
    /// the handful of defaults a test could otherwise leak into later runs —
    /// the editor's persisted language override and the preferences colour
    /// scheme. Has no effect outside of UI testing.
    private func resetStateForUITestsIfRequested() {
        guard ProcessInfo.processInfo.environment["UITEST_RESET_STATE"] == "1" else { return }
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "editorLanguageMode")
        defaults.removeObject(forKey: ScritchColorScheme.userPreferencesSchemeKey)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Memorize app window frame for restoration.
        mainWindow?.saveFrame(usingName: AppDelegate.appWindowName)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @objc func textServiceHandler(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        if let string = pboard.string(forType: NSPasteboard.PasteboardType.string) {
            AppModel.shared.setEditorText(string)
        }
    }

}
