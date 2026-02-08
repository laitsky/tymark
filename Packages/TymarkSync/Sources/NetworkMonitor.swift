import Foundation
import Network
import Combine

// MARK: - Network Monitor

/// Monitors network connectivity using NWPathMonitor and publishes status changes.
@MainActor
public final class NetworkMonitor: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isConnected: Bool = true
    @Published public private(set) var connectionType: ConnectionType = .unknown
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var isConstrained: Bool = false

    // MARK: - Types

    public enum ConnectionType: String, Sendable {
        case wifi
        case cellular
        case wiredEthernet
        case other
        case unknown
    }

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.tymark.network-monitor", qos: .utility)

    // MARK: - Callbacks

    public var onConnectivityChanged: ((Bool) -> Void)?

    // MARK: - Initialization

    public init() {
        self.monitor = NWPathMonitor()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Public API

    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained
                self.connectionType = self.resolveConnectionType(path)

                if wasConnected != self.isConnected {
                    self.onConnectivityChanged?(self.isConnected)
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func stop() {
        monitor.cancel()
    }

    // MARK: - Private Methods

    private func resolveConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else if path.usesInterfaceType(.other) || path.usesInterfaceType(.loopback) {
            return .other
        }
        return .unknown
    }
}
