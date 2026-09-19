import Cocoa
import Carbon.HIToolbox

// Must be a free C function — CGEventTap callback cannot be a closure or method
private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}

class KeystrokeMonitor {
    private var buffer = ""
    private var tap: CFMachPort?

    func start() {
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[DevKit] CGEventTap creation failed — Accessibility permission missing?")
            return
        }
        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[DevKit] Keystroke monitor active. Type ::format \"text\" then Tab.")
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Cmd+Shift+\ — POP hotkey: copy selection, show tone picker
        let flags = event.flags
        if keyCode == kVK_ANSI_Backslash,
           flags.contains(.maskCommand),
           flags.contains(.maskShift) {
            print("[DevKit] Cmd+Shift+\\ detected — POP mode")
            let previousApp = NSWorkspace.shared.frontmostApplication
            DispatchQueue.main.async {
                PopHandler.trigger(previousApp: previousApp)
            }
            return nil // consume hotkey
        }

        switch keyCode {
        case kVK_Tab:
            print("[DevKit] Tab pressed. Buffer: '\(buffer)'")
            if let extracted = extractFormatText() {
                print("[DevKit] Pattern matched. Extracted: '\(extracted)'")
                buffer = ""
                DispatchQueue.main.async {
                    TonePickerPanel.show(text: extracted)
                }
                return nil // consume Tab so it isn't typed into the field
            } else {
                print("[DevKit] No ::format pattern found in buffer.")
            }

        case kVK_Return, kVK_ANSI_KeypadEnter:
            buffer = "" // message sent — reset

        case kVK_Escape:
            buffer = ""

        case kVK_Delete: // backspace
            if !buffer.isEmpty { buffer.removeLast() }

        default:
            if let nsEvent = NSEvent(cgEvent: event),
               let chars = nsEvent.characters, !chars.isEmpty {
                buffer.append(chars)
                if buffer.count > 400 {
                    buffer = String(buffer.suffix(400))
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    // Matches ::format <anything> at the end of the buffer (no quotes needed)
    private func extractFormatText() -> String? {
        let pattern = #"::format (.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: buffer, range: NSRange(buffer.startIndex..., in: buffer)),
              let range = Range(match.range(at: 1), in: buffer) else {
            return nil
        }
        return String(buffer[range]).trimmingCharacters(in: .whitespaces)
    }
}
