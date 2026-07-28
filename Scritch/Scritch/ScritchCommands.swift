//
//  ScritchCommands.swift
//  Scritch
//
//  SwiftUI replacement for `MainMenu.xib`'s custom menu items. The standard
//  App/Edit/Window menus are supplied by SwiftUI itself; this only reproduces
//  what the XIB customised. Menu titles here are load-bearing: the UI test
//  suite locates items by these exact strings (see `UITestSupport.swift`).
//

import SwiftUI

struct ScritchCommands: Commands {

    @ObservedObject var model: AppModel

    var body: some Commands {
        // The XIB's File menu had Clear ⌘N plus Close ⌘W; every other item was
        // `hidden="YES"` dead UI. Close is provided by SwiftUI's window
        // commands, so only Clear needs reproducing.
        CommandGroup(replacing: .newItem) {
            Button("Clear") {
                model.clearEditor()
            }
            .keyboardShortcut("n")
        }

        CommandMenu("Scripts") {
            // Mirrors `AppDelegate.setPopover(isOpen:)`'s isHidden swap: only
            // one of these two items is present at a time.
            if !model.isPickerOpen {
                Button("Open Picker") {
                    model.showPicker()
                }
                .keyboardShortcut("b")
            } else {
                Button("Close Picker") {
                    model.hidePicker()
                }
            }

            Divider()

            Button("Re-execute Last Script") {
                model.runScriptAgain()
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Divider()

            Button("Reload Scripts") {
                model.reloadScripts()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Get more scripts…") {
                model.openScripts()
            }
        }

        CommandGroup(replacing: .help) {
            Button("Scritch Help") {
                model.openHelp()
            }
            .keyboardShortcut("?")

            Divider()

            // The XIB's "@OKatBest on Twitter" item carries no action or
            // target — AppKit disables menu items with no action, so it's
            // decorative dead UI. Reproduced the same way rather than wiring
            // it to a URL that was never actually there.
            Button("@OKatBest on Twitter") {}
                .disabled(true)
        }

        #if !APPSTORE
        CommandGroup(after: .appInfo) {
            Button("Check For Updates") {
                model.checkForUpdates()
            }
        }
        #endif
    }
}
