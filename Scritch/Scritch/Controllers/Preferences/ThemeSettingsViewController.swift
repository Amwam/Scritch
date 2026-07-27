//
//  ThemeSettingsViewController.swift
//  Scritch
//
//  Created by Ivan on 6/18/20.
//  Copyright © 2020 OKatBest. All rights reserved.
//

import Foundation
import Cocoa

enum ScritchColorScheme: Int {
    case system
    case light
    case dark
}

class ThemeSettingsViewController: NSViewController {
    static let userPreferencesSchemeKey = "scritchColorScheme"
    
    static func applyTheme() {
        switch ScritchColorScheme(rawValue: UserDefaults.standard.integer(forKey: "scritchColorScheme")) {
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        default:
            NSApp.appearance = nil
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = view.fittingSize
    }
    @IBAction func didChangeColorTheme(_ sender: Any) {
        ThemeSettingsViewController.applyTheme()
    }
}
