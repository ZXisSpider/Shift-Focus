import Carbon
import Cocoa

enum HotKeyAction {
    case direction(DisplayDirection)
    case displayNumber(Int)
}

private var globalHotKeyCallback: ((HotKeyAction) -> Void)?

final class HotKeyManager {

    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private let signature: OSType = 0x5348464B // 'SHFK'

    deinit { unregister() }

    func register(callback: @escaping (HotKeyAction) -> Void) {
        globalHotKeyCallback = callback

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        guard InstallEventHandler(GetApplicationEventTarget(), carbonHandler, 1, &eventType, nil, &handlerRef) == noErr else {
            Logger.error("Failed to install Carbon event handler")
            return
        }

        registerKey(UInt32(kVK_RightArrow), id: 1,  label: "Ctrl+Option+RightArrow")
        registerKey(UInt32(kVK_LeftArrow),  id: 2,  label: "Ctrl+Option+LeftArrow")
        registerKey(UInt32(kVK_ANSI_1),     id: 10, label: "Ctrl+Option+1")
        registerKey(UInt32(kVK_ANSI_2),     id: 11, label: "Ctrl+Option+2")
        registerKey(UInt32(kVK_ANSI_3),     id: 12, label: "Ctrl+Option+3")
    }

    private func registerKey(_ keyCode: UInt32, id: UInt32, label: String) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = signature
        hotKeyID.id = id

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, UInt32(controlKey | optionKey), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            Logger.error("Failed to register \(label) (err \(status))")
        } else {
            Logger.info("Hotkey registered: \(label)")
            hotKeyRefs.append(ref)
        }
    }

    func unregister() {
        for ref in hotKeyRefs { if let r = ref { UnregisterEventHotKey(r) } }
        hotKeyRefs.removeAll()
        if let ref = handlerRef { RemoveEventHandler(ref); handlerRef = nil }
        globalHotKeyCallback = nil
    }
}

private func carbonHandler(
    _ ref: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                            nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID) == noErr else {
        return OSStatus(eventNotHandledErr)
    }

    let action: HotKeyAction
    switch hotKeyID.id {
    case 1:  action = .direction(.right)
    case 2:  action = .direction(.left)
    case 10: action = .displayNumber(1)
    case 11: action = .displayNumber(2)
    case 12: action = .displayNumber(3)
    default: return noErr
    }

    Logger.debug("Hotkey pressed: id=\(hotKeyID.id)")
    DispatchQueue.main.async { globalHotKeyCallback?(action) }
    return noErr
}
