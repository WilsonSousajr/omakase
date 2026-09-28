import Network

/// Reports each network path update: true when usable, to drain and refresh,
/// and false when not, so the toolbar can say Offline at once (#185).
final class Reachability: Sendable {
    private let monitor = NWPathMonitor()

    func start(onChange: @escaping @Sendable (_ isOnline: Bool) -> Void) {
        monitor.pathUpdateHandler = { path in onChange(path.status == .satisfied) }
        monitor.start(queue: .global(qos: .utility))
    }
}
