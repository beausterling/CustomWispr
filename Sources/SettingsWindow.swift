import Cocoa

class SettingsWindow {
    private var window: NSWindow?
    private var textView: NSTextView?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.minSize = NSSize(width: 400, height: 300)

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Title label
        let titleLabel = NSTextField(labelWithString: "Custom Instructions")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: contentView.bounds.height - 40, width: 480, height: 22)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(titleLabel)

        // Subtitle label
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Add instructions for the AI cleanup model. For example: Replace 'wisprflow' with 'CustomWispr'")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: contentView.bounds.height - 72, width: 480, height: 28)
        subtitleLabel.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(subtitleLabel)

        // Scroll view with text view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: contentView.bounds.width - 40, height: contentView.bounds.height - 140))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = SettingsManager.shared.customInstructions

        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        self.textView = textView

        // Save button
        let saveButton = NSButton(title: "Save", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: contentView.bounds.width - 100, y: 16, width: 80, height: 32)
        saveButton.autoresizingMask = [.minXMargin, .maxYMargin]
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        contentView.addSubview(saveButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    @objc private func saveClicked() {
        if let text = textView?.string {
            SettingsManager.shared.customInstructions = text
            log("Settings saved")
        }
        window?.close()
    }
}
