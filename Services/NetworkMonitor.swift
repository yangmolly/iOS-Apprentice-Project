//
//  NetworkMonitor.swift
//  iOSApprenticeProject
//

import Foundation
import Network
import Observation

@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    /// Called on the main actor each time connectivity comes back.
    var onReconnect: (() -> Void)?

    @ObservationIgnored private let monitor = NWPathMonitor()

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let wasOnline = self.isOnline
                self.isOnline = online
                if online && !wasOnline { self.onReconnect?() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }
}
