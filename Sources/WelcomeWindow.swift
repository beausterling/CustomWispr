import Cocoa
import ServiceManagement

class WelcomeWindow: NSObject {
    private var window: NSWindow?
    var onComplete: (() -> Void)?

    private static var apiFieldKey: UInt8 = 0
    private static var errorLabelKey: UInt8 = 0
    private static var loginCheckboxKey: UInt8 = 0

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hasKey = Config.hasAPIKey

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to CustomWispr"
        window.center()

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        var y = contentView.bounds.height - 50

        // Title
        let titleLabel = NSTextField(labelWithString: "Welcome to CustomWispr")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: y, width: 480, height: 30)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(titleLabel)
        y -= 28

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Speech-to-text for your Mac")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.frame = NSRect(x: 20, y: y, width: 480, height: 20)
        subtitleLabel.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(subtitleLabel)
        y -= 40

        // API Key section
        let apiLabel = NSTextField(labelWithString: "OpenAI API Key")
        apiLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        apiLabel.frame = NSRect(x: 40, y: y, width: 440, height: 18)
        apiLabel.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(apiLabel)
        y -= 28

        let apiField = NSSecureTextField()
        apiField.placeholderString = hasKey ? "API key configured — enter a new one to replace" : "sk-..."
        apiField.frame = NSRect(x: 40, y: y, width: 440, height: 28)
        apiField.autoresizingMask = [.width, .minYMargin]
        apiField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        contentView.addSubview(apiField)
        y -= 24

        // Link to get API key
        let linkButton = NSButton(title: "Get an API key from OpenAI \u{2192}", target: self, action: #selector(openAPIKeyPage))
        linkButton.isBordered = false
        linkButton.attributedTitle = NSAttributedString(
            string: "Get an API key from OpenAI \u{2192}",
            attributes: [
                .foregroundColor: NSColor.linkColor,
                .font: NSFont.systemFont(ofSize: 12),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        linkButton.frame = NSRect(x: 36, y: y, width: 300, height: 18)
        linkButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(linkButton)
        y -= 8

        // Error label (hidden by default)
        let errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont.systemFont(ofSize: 12)
        errorLabel.textColor = .systemRed
        errorLabel.frame = NSRect(x: 40, y: y, width: 440, height: 16)
        errorLabel.autoresizingMask = [.width, .minYMargin]
        errorLabel.isHidden = true
        contentView.addSubview(errorLabel)
        y -= 24

        // Divider
        let divider = NSBox()
        divider.boxType = .separator
        divider.frame = NSRect(x: 40, y: y, width: 440, height: 1)
        divider.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(divider)
        y -= 30

        // Setup instructions
        let setupTitle = NSTextField(labelWithString: "Setup Instructions")
        setupTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        setupTitle.frame = NSRect(x: 40, y: y, width: 440, height: 18)
        setupTitle.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(setupTitle)
        y -= 28

        let steps = [
            "1. System Settings \u{2192} Keyboard \u{2192} Set \"Press \u{1D5F3}\u{1D5FB} key to\" \u{2192} Do Nothing",
            "2. Grant Accessibility permission when prompted (for key monitoring)",
            "3. Grant Microphone permission when prompted (for speech recording)"
        ]

        for step in steps {
            let stepLabel = NSTextField(wrappingLabelWithString: step)
            stepLabel.font = NSFont.systemFont(ofSize: 12)
            stepLabel.textColor = .secondaryLabelColor
            stepLabel.frame = NSRect(x: 56, y: y, width: 420, height: 32)
            stepLabel.autoresizingMask = [.width, .minYMargin]
            contentView.addSubview(stepLabel)
            y -= 34
        }

        y -= 6

        // Launch at Login checkbox
        let loginCheckbox = NSButton(checkboxWithTitle: "Launch CustomWispr at login", target: nil, action: nil)
        loginCheckbox.font = NSFont.systemFont(ofSize: 13)
        loginCheckbox.frame = NSRect(x: 40, y: y, width: 440, height: 20)
        loginCheckbox.autoresizingMask = [.width, .minYMargin]
        loginCheckbox.state = .off
        contentView.addSubview(loginCheckbox)
        y -= 30

        // Get Started button
        let buttonTitle = hasKey ? "Get Started" : "Get Started"
        let startButton = NSButton(title: buttonTitle, target: self, action: #selector(getStartedClicked))
        startButton.bezelStyle = .rounded
        startButton.keyEquivalent = "\r"
        startButton.controlSize = .large
        startButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        startButton.frame = NSRect(x: 190, y: max(y, 20), width: 140, height: 36)
        startButton.autoresizingMask = [.minXMargin, .maxXMargin, .maxYMargin]
        contentView.addSubview(startButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        // Store references for action handlers
        objc_setAssociatedObject(self, &WelcomeWindow.apiFieldKey, apiField, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &WelcomeWindow.errorLabelKey, errorLabel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &WelcomeWindow.loginCheckboxKey, loginCheckbox, .OBJC_ASSOCIATION_RETAIN)
    }

    private var apiField: NSSecureTextField? {
        objc_getAssociatedObject(self, &WelcomeWindow.apiFieldKey) as? NSSecureTextField
    }

    private var errorLabel: NSTextField? {
        objc_getAssociatedObject(self, &WelcomeWindow.errorLabelKey) as? NSTextField
    }

    private var loginCheckbox: NSButton? {
        objc_getAssociatedObject(self, &WelcomeWindow.loginCheckboxKey) as? NSButton
    }

    @objc private func openAPIKeyPage() {
        if let url = URL(string: "https://platform.openai.com/api-keys") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func getStartedClicked() {
        guard let apiField = apiField, let errorLabel = errorLabel else { return }

        let key = apiField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // If no existing key and field is empty, require one
        if !Config.hasAPIKey && key.isEmpty {
            errorLabel.stringValue = "Please enter your OpenAI API key."
            errorLabel.isHidden = false
            return
        }

        // Save new key if entered
        if !key.isEmpty {
            if Config.saveAPIKey(key) {
                log("API key saved from welcome window")
            } else {
                errorLabel.stringValue = "Failed to save API key. Check file permissions."
                errorLabel.isHidden = false
                return
            }
        }

        // Handle Launch at Login
        if let checkbox = loginCheckbox {
            let shouldLaunchAtLogin = checkbox.state == .on
            setLaunchAtLogin(enabled: shouldLaunchAtLogin)
        }

        window?.close()
        onComplete?()
    }

    private func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                    log("Launch at login enabled")
                } else {
                    try service.unregister()
                    log("Launch at login disabled")
                }
            } catch {
                log("Launch at login error: \(error.localizedDescription)")
            }
        }
    }
}
