import Carbon.HIToolbox

/// ⌃⌥H from any app. Carbon's RegisterEventHotKey needs no Accessibility permission,
/// unlike an NSEvent global monitor.
@MainActor
enum GlobalHotKey {
    private static var action: (() -> Void)?
    private static var ref: EventHotKeyRef?

    static func register(_ action: @escaping () -> Void) {
        self.action = action
        guard ref == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { GlobalHotKey.action?() }   // Carbon delivers on the main thread
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x484C_4F57), id: 1)   // 'HLOW'
        RegisterEventHotKey(UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
    }
}
