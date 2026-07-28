//
//  ScritchApp.swift
//  Scritch
//
//  The app's entry point. Replaces `@NSApplicationMain` + `MainMenu.xib`;
//  `AppDelegate` survives via `NSApplicationDelegateAdaptor` for the handful of
//  things SwiftUI's lifecycle doesn't cover (the services provider, applying the
//  colour scheme, the UI-test state reset).
//

import SwiftUI

@main
struct ScritchApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        // The scene autosaves the window frame under its `id` — the defaults
        // key is literally "NSWindow Frame <id>". Using the name the AppKit
        // build saved under means existing users keep their window position
        // instead of getting a one-time reset on upgrade; the scene now owns
        // the frame outright, and `AppDelegate`'s save/restore pair is gone.
        Window("Scritch", id: "scritch.app.window") {
            ContentView()
                .environmentObject(model)
        }
        // Matches the XIB window's original `contentRect`/`minSize` (480×360)
        // rather than an arbitrary new default — first-launch behaviour should
        // be unchanged. A restored frame takes precedence on later launches.
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
