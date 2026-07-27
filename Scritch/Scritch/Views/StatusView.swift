//
//  StatusView.swift
//  Scritch
//
//  Created by Ivan on 1/27/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//
//  All this does now is host `StatusBarView` where the toolbar item lives in
//  MainMenu.xib. It disappears entirely once the window itself is SwiftUI.
//

import Cocoa
import SwiftUI

class StatusView: NSView {

    /// The state this view renders. Settable so a later phase can inject it.
    var store: StatusStore = .shared {
        didSet { installHostingView() }
    }

    private var hostingView: NSHostingView<StatusBarView>?

    override func awakeFromNib() {
        super.awakeFromNib()
        installHostingView()
    }

    private func installHostingView() {
        hostingView?.removeFromSuperview()

        let hosting = NSHostingView(rootView: StatusBarView(store: store))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        hostingView = hosting
    }
}
