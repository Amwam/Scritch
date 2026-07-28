//
//  ScritchApp.swift
//  Scritch
//
//  The app's entry point. Replaces `@NSApplicationMain` + `MainMenu.xib`;
//  `AppDelegate` survives via `NSApplicationDelegateAdaptor` for the handful of
//  things SwiftUI's lifecycle doesn't cover (services provider, window frame
//  autosave). See `MIGRATION.md` for the full rationale.
//

import SwiftUI

@main
struct ScritchApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Window("Scritch", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        // Matches the XIB window's original `contentRect`/`minSize` (480×360)
        // rather than an arbitrary new default — first-launch behaviour should
        // be unchanged. `NSWindow.setFrameUsingName` in `AppDelegate` overrides
        // this on subsequent launches anyway.
        .defaultSize(width: 480, height: 360)
        // The XIB's window used `toolbarStyle="compact"`; `.unifiedCompact` is
        // the closest SwiftUI equivalent (`.unified` is visually taller).
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            ScritchCommands(model: model)
        }

        // Gives Preferences (⌘,) for free; replaces `SettingsWindowController`.
        Settings {
            SettingsView()
        }
    }
}
