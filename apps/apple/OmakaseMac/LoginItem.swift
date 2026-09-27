import ServiceManagement

/// Open at login (#228; parent spec L202), through the system's own login
/// items, so it shows in System Settings > General > Login Items too.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}
