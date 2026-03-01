import Cocoa
import ServiceManagement
import AVFoundation

class WelcomeWindow: NSObject {
    private var window: NSWindow?
    var onComplete: (() -> Void)?

    private static var apiFieldKey: UInt8 = 0
    private static var errorLabelKey: UInt8 = 0
    private static var loginCheckboxKey: UInt8 = 0
    private static var micStatusLabelKey: UInt8 = 0
    private static var micButtonKey: UInt8 = 0
    private static var accessStatusLabelKey: UInt8 = 0
    private static var accessButtonKey: UInt8 = 0

    private var accessibilityPollTimer: Timer?
    private var microphonePollTimer: Timer?

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

        // Permission setup title
        let setupTitle = NSTextField(labelWithString: "Permissions")
        setupTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        setupTitle.frame = NSRect(x: 40, y: y, width: 440, height: 18)
        setupTitle.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(setupTitle)
        y -= 28

        // Row 1: Fn key setting
        let fnLabel = NSTextField(labelWithString: "Set fn key to \"Do Nothing\"")
        fnLabel.font = NSFont.systemFont(ofSize: 12)
        fnLabel.frame = NSRect(x: 56, y: y, width: 260, height: 20)
        fnLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(fnLabel)

        let fnButton = NSButton(title: "Open Settings", target: self, action: #selector(openKeyboardSettings))
        fnButton.bezelStyle = .rounded
        fnButton.controlSize = .small
        fnButton.font = NSFont.systemFont(ofSize: 11)
        fnButton.frame = NSRect(x: 360, y: y - 2, width: 120, height: 24)
        fnButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(fnButton)
        y -= 30

        // Row 2: Accessibility permission
        let accessLabel = NSTextField(labelWithString: "Accessibility (key monitoring)")
        accessLabel.font = NSFont.systemFont(ofSize: 12)
        accessLabel.frame = NSRect(x: 56, y: y, width: 200, height: 20)
        accessLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(accessLabel)

        let accessStatusLabel = NSTextField(labelWithString: "")
        accessStatusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        accessStatusLabel.alignment = .right
        accessStatusLabel.frame = NSRect(x: 240, y: y, width: 110, height: 20)
        accessStatusLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(accessStatusLabel)

        let accessButton = NSButton(title: "Grant Access", target: self, action: #selector(grantAccessibilityClicked))
        accessButton.bezelStyle = .rounded
        accessButton.controlSize = .small
        accessButton.font = NSFont.systemFont(ofSize: 11)
        accessButton.frame = NSRect(x: 360, y: y - 2, width: 120, height: 24)
        accessButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(accessButton)
        y -= 30

        // Row 3: Microphone permission
        let micLabel = NSTextField(labelWithString: "Microphone (speech recording)")
        micLabel.font = NSFont.systemFont(ofSize: 12)
        micLabel.frame = NSRect(x: 56, y: y, width: 200, height: 20)
        micLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(micLabel)

        let micStatusLabel = NSTextField(labelWithString: "")
        micStatusLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        micStatusLabel.alignment = .right
        micStatusLabel.frame = NSRect(x: 240, y: y, width: 110, height: 20)
        micStatusLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(micStatusLabel)

        let micButton = NSButton(title: "Grant Access", target: self, action: #selector(grantMicrophoneClicked))
        micButton.bezelStyle = .rounded
        micButton.controlSize = .small
        micButton.font = NSFont.systemFont(ofSize: 11)
        micButton.frame = NSRect(x: 360, y: y - 2, width: 120, height: 24)
        micButton.autoresizingMask = [.minYMargin]
        contentView.addSubview(micButton)
        y -= 10

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
        objc_setAssociatedObject(self, &WelcomeWindow.micStatusLabelKey, micStatusLabel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &WelcomeWindow.micButtonKey, micButton, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &WelcomeWindow.accessStatusLabelKey, accessStatusLabel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &WelcomeWindow.accessButtonKey, accessButton, .OBJC_ASSOCIATION_RETAIN)

        updatePermissionStatuses()
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

    private var micStatusLabel: NSTextField? {
        objc_getAssociatedObject(self, &WelcomeWindow.micStatusLabelKey) as? NSTextField
    }

    private var micButton: NSButton? {
        objc_getAssociatedObject(self, &WelcomeWindow.micButtonKey) as? NSButton
    }

    private var accessStatusLabel: NSTextField? {
        objc_getAssociatedObject(self, &WelcomeWindow.accessStatusLabelKey) as? NSTextField
    }

    private var accessButton: NSButton? {
        objc_getAssociatedObject(self, &WelcomeWindow.accessButtonKey) as? NSButton
    }

    // MARK: - Permission Checks

    private func isMicrophoneGranted() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func isAccessibilityGranted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func updatePermissionStatuses() {
        if isAccessibilityGranted() {
            accessStatusLabel?.stringValue = "\u{2713} Granted"
            accessStatusLabel?.textColor = .systemGreen
            accessButton?.title = "\u{2713} Granted"
            accessButton?.isEnabled = false
        } else {
            accessStatusLabel?.stringValue = "Needed"
            accessStatusLabel?.textColor = .systemOrange
            accessButton?.title = "Grant Access"
            accessButton?.isEnabled = true
        }

        if isMicrophoneGranted() {
            micStatusLabel?.stringValue = "\u{2713} Granted"
            micStatusLabel?.textColor = .systemGreen
            micButton?.title = "\u{2713} Granted"
            micButton?.isEnabled = false
        } else {
            micStatusLabel?.stringValue = "Needed"
            micStatusLabel?.textColor = .systemOrange
            micButton?.title = "Grant Access"
            micButton?.isEnabled = true
        }
    }

    // MARK: - Permission Actions

    @objc private func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func grantAccessibilityClicked() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let alreadyTrusted = AXIsProcessTrustedWithOptions(options)
        if alreadyTrusted {
            updatePermissionStatuses()
            return
        }
        // Poll every 1s until granted
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if self.isAccessibilityGranted() {
                timer.invalidate()
                self.accessibilityPollTimer = nil
                self.updatePermissionStatuses()
                log("Accessibility permission granted via onboarding")
            }
        }
    }

    @objc private func grantMicrophoneClicked() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.updatePermissionStatuses()
                    if granted {
                        log("Microphone permission granted via onboarding")
                    }
                }
            }
        case .denied, .restricted:
            // Already denied — open System Settings and poll
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
            microphonePollTimer?.invalidate()
            microphonePollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                if self.isMicrophoneGranted() {
                    timer.invalidate()
                    self.microphonePollTimer = nil
                    self.updatePermissionStatuses()
                    log("Microphone permission granted via onboarding (settings)")
                }
            }
        case .authorized:
            updatePermissionStatuses()
        @unknown default:
            break
        }
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

        // Invalidate any running poll timers
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        microphonePollTimer?.invalidate()
        microphonePollTimer = nil

        // Warn if permissions are missing
        let missingPerms = !isAccessibilityGranted() || !isMicrophoneGranted()
        if missingPerms {
            let alert = NSAlert()
            alert.messageText = "Permissions Not Granted"
            alert.informativeText = "Some permissions are still needed for CustomWispr to work properly. Continue anyway?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Continue Anyway")
            alert.addButton(withTitle: "Go Back")
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
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
