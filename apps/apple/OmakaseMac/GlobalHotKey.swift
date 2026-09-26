import Carbon.HIToolbox

/// A system-wide hotkey through Carbon's `RegisterEventHotKey`: it needs no
/// Accessibility permission, which an `NSEvent` global monitor would, and no
/// dependency (M3.5 spec, Decisions). Registered until `unregister()`.
///
///     let hotKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | optionKey)) { show() }
@MainActor
final class GlobalHotKey {
    private let id: UInt32
    private var reference: EventHotKeyRef?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        id = HotKeyRegistry.add(action)
        let hotKeyID = EventHotKeyID(signature: HotKeyRegistry.signature, id: id)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &reference)
    }

    /// ⌥⌘N, the capture default; M5's Settings makes it configurable.
    static func capture(action: @escaping @MainActor () -> Void) -> GlobalHotKey {
        GlobalHotKey(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | optionKey), action: action)
    }

    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        HotKeyRegistry.remove(id)
    }
}

/// The actions by hotkey id. Carbon calls back through a C function pointer,
/// which can capture nothing, so the handler finds its action here.
@MainActor
private enum HotKeyRegistry {
    /// 'OMKS': marks the app's hotkeys among the process's events.
    nonisolated static let signature: OSType = 0x4F4D_4B53
    private static var actions: [UInt32: @MainActor () -> Void] = [:]
    private static var lastID: UInt32 = 0
    private static var isHandlerInstalled = false

    static func add(_ action: @escaping @MainActor () -> Void) -> UInt32 {
        installHandlerOnce()
        lastID += 1
        actions[lastID] = action
        return lastID
    }

    static func remove(_ id: UInt32) { actions[id] = nil }

    static func fire(_ id: UInt32) { actions[id]?() }

    private static func installHandlerOnce() {
        guard !isHandlerInstalled else { return }
        isHandlerInstalled = true
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyPressed, 1, &pressed, nil, nil)
    }
}

/// The Carbon callback: reads which hotkey fired and runs its action on the main actor.
private func hotKeyPressed(_: EventHandlerCallRef?, _ event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr, hotKeyID.signature == HotKeyRegistry.signature else { return OSStatus(eventNotHandledErr) }
    let id = hotKeyID.id
    Task { @MainActor in HotKeyRegistry.fire(id) }
    return noErr
}
