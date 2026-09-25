import Carbon.HIToolbox

/// System-wide shortcuts via Carbon's `RegisterEventHotKey`: no permissions, no dependencies.
@MainActor
final class HotKeys {
    private var actions: [UInt32: @MainActor () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private static let signature: OSType = 0x6D6E_7774 // 'mnwt'

    func register(keyCode: Int, modifiers: Int, action: @escaping @MainActor () -> Void) {
        installHandlerIfNeeded()
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers),
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref
        )
        // Another app may already own the combo; the menu still works, so fail quietly.
        guard status == noErr, let ref else { return }
        refs.append(ref)
        actions[id] = action
    }

    fileprivate func fire(_ id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(), hotKeyCallback, 1, &spec,
            Unmanaged.passUnretained(self).toOpaque(), &handler
        )
    }
}

private func hotKeyCallback(_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &id
    )
    guard status == noErr else { return status }
    // Carbon delivers hot key events on the main thread.
    let hotKeys = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { hotKeys.fire(id.id) }
    return noErr
}
