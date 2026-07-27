//
//  SettingsView.swift
//  Scritch
//
//  SwiftUI replacement for the old Preferences storyboard.
//

import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ScriptsSettingsView()
                .tabItem {
                    Label("Scripts", systemImage: "text.and.command.macwindow")
                }
            ThemeSettingsView()
                .tabItem {
                    Label("Colors", systemImage: "paintpalette")
                }
        }
        .padding(20)
        .frame(width: 480)
    }
}

// MARK: - Scripts

struct ScriptsSettingsView: View {

    private static let helpURL = URL(
        string: "https://github.com/Amwam/Scritch/blob/main/Scritch/Documentation/CustomScripts.md"
    )

    /// Displayed path of the custom scripts folder. Kept in sync with the
    /// `scriptsFolderPath` user default, which is written using
    /// `UserDefaults.set(_: URL, forKey:)` exactly as before.
    @State private var scriptsFolderPath: String = ScriptsSettingsView.storedPath()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom scripts folder location")
                HStack(alignment: .top, spacing: 8) {
                    TextField("", text: .constant(scriptsFolderPath), prompt: Text("Nothing selected :("))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    Button("Change…") {
                        browseForScriptsFolder()
                    }
                    .frame(width: 80)
                }
            }

            Divider()

            HStack {
                Button {
                    openHelp()
                } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .help("Read the documentation about custom scripts")
                .accessibilityLabel("Help")
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func storedPath() -> String {
        UserDefaults.standard.url(forKey: ScriptManager.userPreferencesPathKey)?.path ?? ""
    }

    private func browseForScriptsFolder() {
        let panel = NSOpenPanel()

        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        panel.begin { result in
            do {
                guard let url = panel.url, result == NSApplication.ModalResponse.OK else {
                    return
                }

                UserDefaults.standard.set(url, forKey: ScriptManager.userPreferencesPathKey)

                try ScriptManager.setBookmarkData(url: url)

                scriptsFolderPath = ScriptsSettingsView.storedPath()

            } catch let error {
                print(error)
            }
        }
    }

    private func openHelp() {
        guard let url = ScriptsSettingsView.helpURL else {
            assertionFailure("Could not generate help URL.")
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Colors

struct ThemeSettingsView: View {

    @AppStorage(ScritchColorScheme.userPreferencesSchemeKey)
    private var colorScheme: Int = ScritchColorScheme.system.rawValue

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Text("Color Scheme:")
                    .frame(width: 130, alignment: .trailing)
                Picker("", selection: $colorScheme) {
                    ForEach(ScritchColorScheme.allCases) { scheme in
                        Text(scheme.title).tag(scheme.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 167)
            }
            .frame(width: 300)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
        .onChange(of: colorScheme) { _, _ in
            ScritchColorScheme.applyTheme()
        }
    }
}

#Preview {
    SettingsView()
}
