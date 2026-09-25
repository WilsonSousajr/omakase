import Network

/// Calls back when the network path becomes usable, to drain and refresh.
final class Reachability: Sendable {
    private let monitor = NWPathMonitor()

    func start(onOnline: @escaping @Sendable () -> Void) {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied { onOnline() }
        }
        monitor.start(queue: .global(qos: .utility))
    }
}
