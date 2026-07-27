//
//  StatusView.swift
//  Scritch
//
//  Created by Ivan on 1/27/19.
//  Copyright © 2019 OKatBest. All rights reserved.
//

import Cocoa
import Combine

@IBDesignable
class StatusView: NSView {

    let transitionLength = 0.3

    @IBOutlet weak var textLabel: NSTextField!
    @IBOutlet weak var updateLabel: UpdateTextField!

    /// The state this view renders. Settable so a later phase can inject it.
    var store: StatusStore = .shared {
        didSet { observeStore() }
    }

    private var current = Status.normal
    private var cancellable: AnyCancellable?

    override func awakeFromNib() {
        super.awakeFromNib()

        self.wantsLayer = true

        self.layer?.backgroundColor = ColorPair.normal.value(for: self.effectiveAppearance).cgColor
        self.layer?.cornerRadius = 5

        observeStore()
    }

    private func observeStore() {
        // `@Published` replays the current value on subscribe, so this also
        // performs the initial render.
        cancellable = store.$current.sink { [weak self] status in
            self?.render(status)
        }
    }

    private func render(_ newStatus: Status) {
        self.current = newStatus
        self.updateText(newStatus)
        self.updateColor(newStatus)
    }

    fileprivate func updateText(_ newStatus: Status) {

        var text = ""

        self.updateLabel.isHidden = true

        switch newStatus {
        case .help(let value):
            text = value
        case .info(let value):
            text = value
        case .error(let value):
            text = value
        case .success(let value):
            text = value
        case .normal:
            text = "Press ⌘+B to get started"
        case .updateAvailable(let link):
            text = "New version available! "

            self.updateLabel.isHidden = false
            self.updateLabel.link = link

        }

        self.textLabel.stringValue = text
    }

    fileprivate func fadeText(to alphaValue: CGFloat, completionHandler: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = self.transitionLength / 2.5
            self.textLabel.animator().alphaValue = alphaValue
        }) {
            completionHandler?()
        }
    }

    fileprivate func updateColor(_ newStatus: Status) {

        var color = ColorPair.normal

        switch newStatus {
        case .normal, .help(_):
            break
        case .success(_):
            color = ColorPair.green.swap
        case .info(_):
            color = ColorPair.blue.swap
        case .error(_):
            color = ColorPair.red.swap
        case .updateAvailable:
            color = ColorPair.purple
        }

        self.layer?.backgroundColor = color.value(for: self.effectiveAppearance).cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        self.updateColor(self.current)
    }
}
