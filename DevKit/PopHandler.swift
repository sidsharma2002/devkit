import Cocoa

struct PopHandler {

    /// Called when Cmd+Shift+\ is pressed.
    /// Copies current selection into clipboard, reads it, shows tone picker in POP mode.
    static func trigger(previousApp: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        let savedClipboard = pasteboard.string(forType: .string)

        // Clear clipboard so we can detect if Cmd+C actually copied something
        pasteboard.clearContents()

        let src = CGEventSource(stateID: .hidSystemState)

        // Post Cmd+C to copy selected text — goes to annotated tap, bypasses our monitor
        postKey(0x08, flags: .maskCommand, source: src, down: true)
        postKey(0x08, flags: .maskCommand, source: src, down: false)

        // Wait for clipboard to populate, then read and show picker
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let selected = pasteboard.string(forType: .string) ?? ""

            // Restore original clipboard regardless
            pasteboard.clearContents()
            if let saved = savedClipboard {
                pasteboard.setString(saved, forType: .string)
            }

            guard !selected.isEmpty else {
                print("[DevKit] POP: nothing selected or clipboard empty — aborting")
                return
            }

            print("[DevKit] POP: selected text = '\(selected)'")
            TonePickerPanel.showPop(text: selected, previousApp: previousApp)
        }
    }

    private static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags, source: CGEventSource?, down: Bool) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
