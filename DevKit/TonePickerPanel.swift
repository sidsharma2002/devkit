import Cocoa
import Carbon.HIToolbox

class TonePickerPanel: NSPanel {

    enum Mode {
        case format  // ::format trigger — Cmd+A then Cmd+V
        case pop     // hotkey trigger — selection active, just Cmd+V
    }

    struct ToneOption {
        let name: String
        let icon: String        // SF Symbol name
        let description: String
    }

    static let options: [ToneOption] = [
        ToneOption(name: "Formal",          icon: "doc.text.fill",       description: "Structured incident report"),
        ToneOption(name: "Diplomatic",      icon: "person.wave.2.fill",  description: "Warm, blame-free update"),
        ToneOption(name: "Direct",          icon: "bolt.fill",           description: "Two sentences, no fluff"),
        ToneOption(name: "Management",      icon: "chart.bar.doc.horizontal.fill", description: "Executive summary with impact"),
        ToneOption(name: "Junior-friendly", icon: "graduationcap.fill",  description: "Plain English, step-by-step"),
    ]

    static var current: TonePickerPanel?

    private var tableView: NSTableView!
    private var hintLabel: NSTextField!
    private var isLoading = false
    private var originalText = ""
    private var mode: Mode = .format
    private var previousApp: NSRunningApplication?

    // MARK: - Factory

    static func show(text: String) {
        let previousApp = NSWorkspace.shared.frontmostApplication
        let panel = makePanel()
        panel.originalText = text
        panel.previousApp = previousApp
        panel.mode = .format
        panel.setup()
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        print("[DevKit] Panel shown for text: '\(text)'")
        current = panel
    }

    static func showPop(text: String, previousApp: NSRunningApplication?) {
        let panel = makePanel()
        panel.originalText = text
        panel.previousApp = previousApp
        panel.mode = .pop
        panel.setup()
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        print("[DevKit] POP panel shown for: '\(text)'")
        current = panel
    }

    private static func makePanel() -> TonePickerPanel {
        TonePickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 344),
            styleMask: [.titled, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )
    }

    // MARK: - Setup

    private func setup() {
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isFloatingPanel = true
        level = .floating
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true

        guard let contentView = contentView else { return }
        let W: CGFloat = 300
        let H: CGFloat = 344
        let hintH: CGFloat = 34
        let headerH: CGFloat = 44
        let tableH: CGFloat = H - headerH - hintH

        // Header label
        let header = NSTextField(labelWithString: "SELECT TONE")
        header.font = .systemFont(ofSize: 10, weight: .semibold)
        header.textColor = NSColor.white.withAlphaComponent(0.35)
        header.alignment = .center
        header.frame = NSRect(x: 0, y: H - headerH, width: W, height: headerH)
        header.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(header)

        // Separator below header
        let topSep = makeHairline(x: 16, y: H - headerH, width: W - 32)
        contentView.addSubview(topSep)

        // Table
        let scrollView = NSScrollView()
        scrollView.frame = NSRect(x: 0, y: hintH, width: W, height: tableH)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.focusRingType = .none
        tableView.backgroundColor = .clear
        tableView.rowHeight = 52
        tableView.selectionHighlightStyle = .sourceList
        tableView.intercellSpacing = NSSize(width: 0, height: 4)

        let col = NSTableColumn(identifier: .init("tone"))
        col.width = W
        tableView.addTableColumn(col)

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        // Separator above hint
        let botSep = makeHairline(x: 16, y: hintH, width: W - 32)
        contentView.addSubview(botSep)

        // Hint label
        hintLabel = NSTextField(labelWithString: "↑↓  navigate     ↩  select     esc  cancel")
        hintLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.25)
        hintLabel.alignment = .center
        hintLabel.frame = NSRect(x: 0, y: 0, width: W, height: hintH)
        hintLabel.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(hintLabel)
    }

    private func makeHairline(x: CGFloat, y: CGFloat, width: CGFloat) -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.frame = NSRect(x: x, y: y, width: width, height: 1)
        box.autoresizingMask = [.width]
        return box
    }

    // MARK: - Keyboard navigation

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if isLoading { return }
        switch Int(event.keyCode) {
        case kVK_UpArrow:
            let next = max(0, tableView.selectedRow - 1)
            tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)

        case kVK_DownArrow:
            let next = min(Self.options.count - 1, tableView.selectedRow + 1)
            tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)

        case kVK_Return, kVK_ANSI_KeypadEnter:
            confirm()

        case kVK_Escape:
            dismiss()

        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Actions

    private func confirm() {
        guard !isLoading else { return }
        isLoading = true

        let tone = Self.options[tableView.selectedRow].name
        let app = previousApp
        let currentMode = mode

        hintLabel.stringValue = "Formatting with Claude..."
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.5)

        ClaudeRunner.format(text: originalText, tone: tone) { [weak self] formatted in
            self?.close()
            Self.current = nil

            app?.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                switch currentMode {
                case .format:
                    TextReplacer.replace(with: formatted)
                case .pop:
                    TextReplacer.pasteOnly(with: formatted)
                }
            }
        }
    }

    private func dismiss() {
        close()
        Self.current = nil
        previousApp?.activate(options: [.activateIgnoringOtherApps])
    }
}

// MARK: - Table data source / delegate

extension TonePickerPanel: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { Self.options.count }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 52 }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let option = Self.options[row]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 52))

        // SF Symbol icon
        let iconView = NSImageView(frame: NSRect(x: 18, y: 14, width: 22, height: 22))
        let symConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        iconView.image = NSImage(systemSymbolName: option.icon, accessibilityDescription: nil)?
            .withSymbolConfiguration(symConfig)
        iconView.contentTintColor = NSColor.white.withAlphaComponent(0.8)
        container.addSubview(iconView)

        // Tone name
        let nameLabel = NSTextField(labelWithString: option.name)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.frame = NSRect(x: 50, y: 28, width: 234, height: 16)
        container.addSubview(nameLabel)

        // Description
        let descLabel = NSTextField(labelWithString: option.description)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = NSColor.white.withAlphaComponent(0.4)
        descLabel.frame = NSRect(x: 50, y: 10, width: 234, height: 14)
        container.addSubview(descLabel)

        return container
    }
}
