import Cocoa

struct TextReplacer {

    /// Selects all text in the active field and replaces with `text`.
    /// Pastes as both HTML + plain text — Lark renders markdown formatting correctly.
    static func replace(with text: String) {
        let pasteboard = NSPasteboard.general
        let savedString = pasteboard.string(forType: .string)

        writeToClipboard(text, pasteboard: pasteboard)

        let src = CGEventSource(stateID: .hidSystemState)

        // Cmd+A — select all
        postKey(0x00, flags: .maskCommand, source: src, down: true)
        postKey(0x00, flags: .maskCommand, source: src, down: false)

        Thread.sleep(forTimeInterval: 0.04)

        // Cmd+V — paste
        postKey(0x09, flags: .maskCommand, source: src, down: true)
        postKey(0x09, flags: .maskCommand, source: src, down: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let saved = savedString { pasteboard.setString(saved, forType: .string) }
        }
    }

    /// Paste-only — use in POP mode where text is already selected.
    static func pasteOnly(with text: String) {
        let pasteboard = NSPasteboard.general
        let savedString = pasteboard.string(forType: .string)

        writeToClipboard(text, pasteboard: pasteboard)

        let src = CGEventSource(stateID: .hidSystemState)
        postKey(0x09, flags: .maskCommand, source: src, down: true)
        postKey(0x09, flags: .maskCommand, source: src, down: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let saved = savedString { pasteboard.setString(saved, forType: .string) }
        }
    }

    // MARK: - Clipboard

    /// Writes text as both HTML and plain text.
    /// Lark (Electron) prefers HTML — markdown formatting renders correctly.
    /// Falls back to plain text in apps that don't support HTML paste.
    private static func writeToClipboard(_ text: String, pasteboard: NSPasteboard) {
        let html = markdownToHTML(text)
        pasteboard.clearContents()
        pasteboard.setString(html, forType: NSPasteboard.PasteboardType(rawValue: "public.html"))
        pasteboard.setString(text, forType: .string)
    }

    /// Converts Lark markdown to HTML so pasted text renders with formatting.
    private static func markdownToHTML(_ text: String) -> String {
        var html = text

        // Escape HTML special chars first
        html = html.replacingOccurrences(of: "&", with: "&amp;")
        html = html.replacingOccurrences(of: "<", with: "&lt;")
        html = html.replacingOccurrences(of: ">", with: "&gt;")

        // **bold**
        html = html.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<b>$1</b>", options: .regularExpression)
        // *italic*
        html = html.replacingOccurrences(of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, with: "<i>$1</i>", options: .regularExpression)
        // `inline code`
        html = html.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        // newlines → <br>
        html = html.replacingOccurrences(of: "\n", with: "<br>")

        return "<html><body style=\"font-family: sans-serif;\">\(html)</body></html>"
    }

    // MARK: - Key events

    private static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags, source: CGEventSource?, down: Bool) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
