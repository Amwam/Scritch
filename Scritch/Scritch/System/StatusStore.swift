//
//  StatusStore.swift
//  Scritch
//
//  Owns the status bar's state and its queueing/timing behaviour, so that the
//  system layer (ScriptManager, UpdateBuddy, …) never has to talk to a view.
//  `StatusBarView` is a dumb renderer that observes this store.
//

import Foundation
import Combine

enum Status {
    case normal
    case updateAvailable(String)
    case help(String)
    case info(String)
    case error(String)
    case success(String)
}

final class StatusStore: ObservableObject {

    /// Shared instance. `ScriptManager` and `UpdateBuddy` are plain objects
    /// owned by `AppModel` rather than SwiftUI views, so they can't read a store
    /// out of the environment and default to this one. Every consumer holds it
    /// through a settable property so it can still be injected.
    static let shared = StatusStore()

    /// How long a queued (non-skipping) status stays on screen.
    let messageLength = 10.0

    /// The status that should currently be displayed.
    @Published private(set) var current: Status = .normal

    private var queue = [Status]()
    private var running = false

    func setStatus(_ newStatus: Status) {

        switch newStatus {
        case .normal, .help, .updateAvailable:
            // Skip the queue for those statuses
            running = false
            queue.removeAll()
            current = newStatus
        default:
            queue.append(newStatus)
            queueUpdated()
        }
    }

    private func queueUpdated() {
        guard !running else {
            return
        }

        guard !queue.isEmpty else {
            running = false
            current = .normal
            return
        }

        running = true

        current = queue.removeFirst()

        DispatchQueue.main.asyncAfter(deadline: .now() + messageLength, execute: {
            self.running = false
            self.queueUpdated()
        })
    }
}
