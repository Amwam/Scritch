//
//  AppDelegate.swift
//  Scritch
//
//  Created by Ivan on 1/26/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//
//  Slimmed to what `NSApplicationDelegateAdaptor` needs and `Scene`s don't
//  cover: the UI-test state reset, `applyTheme()` and the Services provider.
//  Everything else (menus, preferences, the picker/script actions) moved to
//  `AppModel` and `ScritchCommands` in Phase 4; the window frame is autosaved
//  by the `Window` scene itself — see `ScritchApp`.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        resetStateForUITestsIfRequested()

        ScritchColorScheme.applyTheme()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.servicesProvider = self
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
        // SwiftUI's `Settings` scene remembers which tab was last open. Without
        // this, a run that ends on the Colors tab makes the next run start
        // there, and any test asserting on the default tab fails. Added in
        // Phase 4a — the old NSWindowController-hosted Preferences didn't
        // persist tab selection at all.
        defaults.removeObject(forKey: "com_apple_SwiftUI_Settings_selectedTabIndex")
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
