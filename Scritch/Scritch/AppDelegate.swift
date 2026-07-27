//
//  AppDelegate.swift
//  Scritch
//
//  Created by Ivan on 1/26/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var openPickerMenuItem: NSMenuItem!
    @IBOutlet weak var closePickerMenuItem: NSMenuItem!
    
    @IBOutlet weak var popoverViewController: PopoverViewController!
    @IBOutlet weak var scriptManager: ScriptManager!
    @IBOutlet weak var editor: CodeEditorView!

    // Frame auto save name for app window frame restoration.
    private static let appWindowName = "scritch.app.window"
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        resetStateForUITestsIfRequested()

        ScritchColorScheme.applyTheme()

        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.servicesProvider = self

        // Restore app window frame.
        window.setFrameUsingName(AppDelegate.appWindowName)
    }

    /// UI tests launch the (sandboxed) app as a persistent process whose
    /// `UserDefaults` survive between test runs. To keep the suite hermetic,
    /// tests pass `UITEST_RESET_STATE=1` in `launchEnvironment`, which wipes the
    /// handful of defaults a test could otherwise leak into later runs — the
    /// editor's persisted language override and the preferences colour scheme.
    /// Has no effect outside of UI testing.
    private func resetStateForUITestsIfRequested() {
        guard ProcessInfo.processInfo.environment["UITEST_RESET_STATE"] == "1" else { return }
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "editorLanguageMode")
        defaults.removeObject(forKey: ScritchColorScheme.userPreferencesSchemeKey)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Memorize app window frame for restoration.
        window.saveFrame(usingName: AppDelegate.appWindowName)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @IBAction func showPreferencesWindow(_ sender: NSMenuItem) {
        SettingsWindowController.shared.show(sender)
    }
    
    // Menu Stuff
    
    @IBAction func openPickerMenu(_ sender: NSMenuItem) {
        popoverViewController.show()
    }
    
    @IBAction func closePickerMenu(_ sender: Any) {
        popoverViewController.hide()
    }
    
    @IBAction func executeLastScript(_ sender: Any) {
        popoverViewController.runScriptAgain()
    }
    
    @IBAction func reloadScripts(_ sender: Any) {
        scriptManager.reloadScripts()
    }
    
    func setPopover(isOpen: Bool) {
        closePickerMenuItem.isHidden = !isOpen
        openPickerMenuItem.isHidden = isOpen
    }

    @objc func textServiceHandler(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        if let string = pboard.string(forType: NSPasteboard.PasteboardType.string) {
            editor.text = string
        }
    }

}

