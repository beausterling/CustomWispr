import Cocoa
import ServiceManagement
import AVFoundation

class WelcomeWindow: NSObject, NSTextFieldDelegate {
    private var window: NSWindow?
    var onComplete: (() -> Void)?

    private var currentStep = 0
    private let totalSteps = 6

    // API key masking
    private var apiKeyValue = ""
    private var isUpdatingMask = false
    private weak var apiKeyTextField: NSTextField?
    private weak var apiKeyErrorLabel: NSTextField?

    // Permission polling
    private var accessibilityPollTimer: Timer?
    private var microphonePollTimer: Timer?

    // Weak refs for permission status updates
    private weak var accessibilityStatusView: NSView?
    private weak var accessibilityStatusLabel: NSTextField?
    private weak var accessibilityActionButton: NSButton?
    private weak var microphoneStatusView: NSView?
    private weak var microphoneStatusLabel: NSTextField?
    private weak var microphoneActionButton: NSButton?
    private weak var nextButtonRef: NSButton?

    // MARK: - Colors (matching customwispr-site)

    private let bgColor = NSColor(red: 0x0e/255.0, green: 0x0e/255.0, blue: 0x10/255.0, alpha: 1.0)
    private let textColor = NSColor(red: 0xe8/255.0, green: 0xe6/255.0, blue: 0xe3/255.0, alpha: 1.0)
    private let mutedColor = NSColor(red: 0x94/255.0, green: 0x92/255.0, blue: 0x9d/255.0, alpha: 1.0)
    private let accentColor = NSColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 1.0)
    private let borderColor = NSColor(white: 1.0, alpha: 0.08)
    private let cardBgColor = NSColor(white: 1.0, alpha: 0.03)
    private let greenColor = NSColor(red: 0x22/255.0, green: 0xc5/255.0, blue: 0x5e/255.0, alpha: 1.0)

    // MARK: - Show

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "CustomWispr"
        win.center()
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = bgColor
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true

        self.window = win
        currentStep = 0
        apiKeyValue = ""
        buildStep()

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Step Builder

    private func buildStep() {
        guard let window = window else { return }

        // Clean up timers when leaving permission steps
        if currentStep != 2 {
            accessibilityPollTimer?.invalidate()
            accessibilityPollTimer = nil
        }
        if currentStep != 3 {
            microphonePollTimer?.invalidate()
            microphonePollTimer = nil
        }

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = bgColor.cgColor

        switch currentStep {
        case 0: buildWelcomeStep(in: contentView)
        case 1: buildFnKeyStep(in: contentView)
        case 2: buildAccessibilityStep(in: contentView)
        case 3: buildMicrophoneStep(in: contentView)
        case 4: buildAPIKeyStep(in: contentView)
        case 5: buildFinishStep(in: contentView)
        default: break
        }

        // Step indicator dots (steps 1-5)
        if currentStep > 0 {
            addStepIndicator(to: contentView)
        }

        window.contentView = contentView
    }

    // MARK: - Step 0: Welcome

    private func buildWelcomeStep(in container: NSView) {
        let width = container.bounds.width
        let centerX = width / 2

        // App icon
        let iconSize: CGFloat = 80
        let iconView = NSImageView(frame: NSRect(
            x: centerX - iconSize / 2, y: 300,
            width: iconSize, height: iconSize
        ))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.autoresizingMask = [.minXMargin, .maxXMargin]
        container.addSubview(iconView)

        // Title
        let title = makeLabel("Welcome to CustomWispr", size: 24, weight: .bold, color: textColor)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 255, width: width - 40, height: 32)
        title.autoresizingMask = [.width]
        container.addSubview(title)

        // Subtitle
        let subtitle = makeLabel("Speech-to-text for your Mac", size: 15, weight: .regular, color: mutedColor)
        subtitle.alignment = .center
        subtitle.frame = NSRect(x: 20, y: 225, width: width - 40, height: 22)
        subtitle.autoresizingMask = [.width]
        container.addSubview(subtitle)

        // Get Started button
        let button = makeAmberButton(title: "Get Started", target: self, action: #selector(nextStep))
        button.frame = NSRect(x: centerX - 80, y: 160, width: 160, height: 44)
        button.autoresizingMask = [.minXMargin, .maxXMargin]
        container.addSubview(button)
    }

    // MARK: - Step 1: Fn Key

    private func buildFnKeyStep(in container: NSView) {
        let width = container.bounds.width

        let title = makeLabel("Configure Fn Key", size: 22, weight: .bold, color: textColor)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 380, width: width - 40, height: 30)
        title.autoresizingMask = [.width]
        container.addSubview(title)

        let desc = makeLabel(
            "CustomWispr uses the fn key to start recording.\nSet your fn key to \"Do Nothing\" in System Settings.",
            size: 14, weight: .regular, color: mutedColor
        )
        desc.alignment = .center
        desc.maximumNumberOfLines = 3
        desc.frame = NSRect(x: 40, y: 320, width: width - 80, height: 50)
        desc.autoresizingMask = [.width]
        container.addSubview(desc)

        // Card with instructions
        let card = makeCard(frame: NSRect(x: 60, y: 195, width: width - 120, height: 110))
        container.addSubview(card)

        let step1 = makeLabel("1. Open System Settings > Keyboard", size: 13, weight: .regular, color: textColor)
        step1.frame = NSRect(x: 20, y: 75, width: card.bounds.width - 40, height: 18)
        card.addSubview(step1)

        let step2 = makeLabel("2. Set \"Press fn key to\" to \"Do Nothing\"", size: 13, weight: .regular, color: textColor)
        step2.frame = NSRect(x: 20, y: 50, width: card.bounds.width - 40, height: 18)
        card.addSubview(step2)

        let openBtn = makeSecondaryButton(title: "Open Keyboard Settings", target: self, action: #selector(openKeyboardSettings))
        openBtn.frame = NSRect(x: (card.bounds.width - 200) / 2, y: 10, width: 200, height: 32)
        card.addSubview(openBtn)

        addNavigationButtons(to: container, showBack: true)
    }

    // MARK: - Step 2: Accessibility

    private func buildAccessibilityStep(in container: NSView) {
        let width = container.bounds.width
        let granted = isAccessibilityGranted()

        let title = makeLabel("Accessibility Permission", size: 22, weight: .bold, color: textColor)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 380, width: width - 40, height: 30)
        title.autoresizingMask = [.width]
        container.addSubview(title)

        let desc = makeLabel(
            "CustomWispr needs Accessibility access to\nmonitor the fn key and inject transcribed text.",
            size: 14, weight: .regular, color: mutedColor
        )
        desc.alignment = .center
        desc.maximumNumberOfLines = 3
        desc.frame = NSRect(x: 40, y: 320, width: width - 80, height: 44)
        desc.autoresizingMask = [.width]
        container.addSubview(desc)

        // Status indicator
        let statusDot = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 5
        statusDot.layer?.backgroundColor = (granted ? greenColor : accentColor).cgColor

        let statusLabel = makeLabel(
            granted ? "Permission Granted" : "Permission Needed",
            size: 14, weight: .medium,
            color: granted ? greenColor : accentColor
        )

        let statusContainer = NSView(frame: NSRect(x: 0, y: 270, width: width, height: 20))
        statusContainer.autoresizingMask = [.width]

        let labelWidth: CGFloat = granted ? 150 : 140
        let totalWidth = 10 + 8 + labelWidth
        let startX = (width - totalWidth) / 2

        statusDot.frame = NSRect(x: startX, y: 5, width: 10, height: 10)
        statusLabel.frame = NSRect(x: startX + 18, y: 0, width: labelWidth, height: 20)

        statusContainer.addSubview(statusDot)
        statusContainer.addSubview(statusLabel)
        container.addSubview(statusContainer)

        self.accessibilityStatusView = statusDot
        self.accessibilityStatusLabel = statusLabel

        if !granted {
            let grantBtn = makeAmberButton(title: "Grant Accessibility Access", target: self, action: #selector(grantAccessibilityClicked))
            grantBtn.frame = NSRect(x: (width - 240) / 2, y: 215, width: 240, height: 44)
            grantBtn.autoresizingMask = [.minXMargin, .maxXMargin]
            container.addSubview(grantBtn)
            self.accessibilityActionButton = grantBtn
        }

        addNavigationButtons(to: container, showBack: true)

        // Start polling if not yet granted
        if !granted {
            startAccessibilityPolling()
        }
    }

    // MARK: - Step 3: Microphone

    private func buildMicrophoneStep(in container: NSView) {
        let width = container.bounds.width
        let granted = isMicrophoneGranted()

        let title = makeLabel("Microphone Permission", size: 22, weight: .bold, color: textColor)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 380, width: width - 40, height: 30)
        title.autoresizingMask = [.width]
        container.addSubview(title)

        let desc = makeLabel(
            "CustomWispr needs Microphone access to\nrecord your speech for transcription.",
            size: 14, weight: .regular, color: mutedColor
        )
        desc.alignment = .center
        desc.maximumNumberOfLines = 3
        desc.frame = NSRect(x: 40, y: 320, width: width - 80, height: 44)
        desc.autoresizingMask = [.width]
        container.addSubview(desc)

        // Status indicator
        let statusDot = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 5
        statusDot.layer?.backgroundColor = (granted ? greenColor : accentColor).cgColor

        let statusLabel = makeLabel(
            granted ? "Permission Granted" : "Permission Needed",
            size: 14, weight: .medium,
            color: granted ? greenColor : accentColor
        )

        let statusContainer = NSView(frame: NSRect(x: 0, y: 270, width: width, height: 20))
        statusContainer.autoresizingMask = [.width]

        let labelWidth: CGFloat = granted ? 150 : 140
        let totalWidth = 10 + 8 + labelWidth
        let startX = (width - totalWidth) / 2

        statusDot.frame = NSRect(x: startX, y: 5, width: 10, height: 10)
        statusLabel.frame = NSRect(x: startX + 18, y: 0, width: labelWidth, height: 20)

        statusContainer.addSubview(statusDot)
        statusContainer.addSubview(statusLabel)
        container.addSubview(statusContainer)

        self.microphoneStatusView = statusDot
        self.microphoneStatusLabel = statusLabel

        if !granted {
            let grantBtn = makeAmberButton(title: "Grant Microphone Access", target: self, action: #selector(grantMicrophoneClicked))
            grantBtn.frame = NSRect(x: (width - 240) / 2, y: 215, width: 240, height: 44)
            grantBtn.autoresizingMask = [.minXMargin, .maxXMargin]
            container.addSubview(grantBtn)
            self.microphoneActionButton = grantBtn
        }

        addNavigationButtons(to: container, showBack: true)

        if !granted {
            startMicrophonePolling()
        }
    }

    // MARK: - Step 4: API Key

    private func buildAPIKeyStep(in container: NSView) {
        let width = container.bounds.width

        let title = makeLabel("OpenAI API Key", size: 22, weight: .bold, color: textColor)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 380, width: width - 40, height: 30)
        title.autoresizingMask = [.width]
        container.addSubview(title)

        let desc = makeLabel(
            "Enter your OpenAI API key to enable\nspeech-to-text transcription.",
            size: 14, weight: .regular, color: mutedColor
        )
        desc.alignment = .center
        desc.maximumNumberOfLines = 2
        desc.frame = NSRect(x: 40, y: 335, width: width - 80, height: 40)
        desc.autoresizingMask = [.width]
        container.addSubview(desc)

        // API key text field (regular, with custom masking)
        let field = NSTextField()
        field.placeholderString = Config.hasAPIKey ? "API key configured \u{2014} enter new to replace" : "sk-..."
        field.frame = NSRect(x: 60, y: 285, width: width - 120, height: 36)
        field.autoresizingMask = [.width]
        field.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.cell?.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.wantsLayer = true
        field.layer?.cornerRadius = 8
        field.layer?.borderWidth = 1
        field.layer?.borderColor = borderColor.cgColor
        field.backgroundColor = NSColor(white: 1.0, alpha: 0.05)
        field.textColor = textColor
        field.focusRingType = .none
        field.delegate = self
        container.addSubview(field)
        self.apiKeyTextField = field

        // "Get an API key" link
        let linkButton = NSButton(title: "Get an API key from OpenAI \u{2192}", target: self, action: #selector(openAPIKeyPage))
        linkButton.isBordered = false
        linkButton.attributedTitle = NSAttributedString(
            string: "Get an API key from OpenAI \u{2192}",
            attributes: [
                .foregroundColor: accentColor,
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        linkButton.frame = NSRect(x: 60, y: 255, width: 250, height: 20)
        linkButton.autoresizingMask = [.minYMargin]
        container.addSubview(linkButton)

        // Error label
        let errorLabel = makeLabel("", size: 12, weight: .medium, color: NSColor.systemRed)
        errorLabel.frame = NSRect(x: 60, y: 230, width: width - 120, height: 18)
        errorLabel.autoresizingMask = [.width]
        errorLabel.isHidden = true
        container.addSubview(errorLabel)
        self.apiKeyErrorLabel = errorLabel

        addNavigationButtons(to: container, showBack: true)
    }

    // MARK: - Step 5: Finish

    private func buildFinishStep(in container: NSView) {
        let width = container.bounds.width

        let title = makeLabel("You're all set!", size: 22, weight: .bold, color: textColor)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: 385, width: width - 40, height: 30)
        title.autoresizingMask = [.width]
        container.addSubview(title)

        let desc = makeLabel(
            "Hold the fn key to record, release to transcribe.",
            size: 14, weight: .regular, color: mutedColor
        )
        desc.alignment = .center
        desc.frame = NSRect(x: 40, y: 350, width: width - 80, height: 20)
        desc.autoresizingMask = [.width]
        container.addSubview(desc)

        let promptLabel = makeLabel(
            "Use this prompt to customize your app with AI:",
            size: 14, weight: .regular, color: mutedColor
        )
        promptLabel.alignment = .center
        promptLabel.frame = NSRect(x: 40, y: 308, width: width - 80, height: 20)
        promptLabel.autoresizingMask = [.width]
        container.addSubview(promptLabel)

        // Code block
        let codeText = "Fork and clone https://github.com/beausterling/CustomWispr \u{2014} it\u{2019}s a macOS menu bar speech-to-text app built in Swift. Read the README and codebase, then help me customize it."

        let codeCard = makeCard(frame: NSRect(x: 40, y: 185, width: width - 80, height: 120))
        container.addSubview(codeCard)

        let codeLabel = NSTextField(wrappingLabelWithString: codeText)
        codeLabel.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        codeLabel.textColor = textColor
        codeLabel.backgroundColor = .clear
        codeLabel.isEditable = false
        codeLabel.isSelectable = true
        codeLabel.isBordered = false
        codeLabel.frame = NSRect(x: 16, y: 36, width: codeCard.bounds.width - 32, height: 72)
        codeLabel.autoresizingMask = [.width]
        codeCard.addSubview(codeLabel)

        // Copy button inside code block
        let copyBtn = makeSecondaryButton(title: "Copy", target: self, action: #selector(copyPrompt))
        copyBtn.frame = NSRect(x: codeCard.bounds.width - 80, y: 6, width: 64, height: 26)
        copyBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        codeCard.addSubview(copyBtn)

        // BuyMeACoffee link
        let coffeeButton = NSButton(title: "Buy Me a Coffee \u{2615}", target: self, action: #selector(openBuyMeACoffee))
        coffeeButton.isBordered = false
        coffeeButton.attributedTitle = NSAttributedString(
            string: "Buy Me a Coffee \u{2615}",
            attributes: [
                .foregroundColor: accentColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        coffeeButton.frame = NSRect(x: (width - 160) / 2, y: 148, width: 160, height: 22)
        coffeeButton.autoresizingMask = [.minXMargin, .maxXMargin]
        container.addSubview(coffeeButton)

        // Finish button
        let finishBtn = makeAmberButton(title: "Finish Setup", target: self, action: #selector(finishClicked))
        finishBtn.frame = NSRect(x: (width - 160) / 2, y: 90, width: 160, height: 44)
        finishBtn.autoresizingMask = [.minXMargin, .maxXMargin]
        container.addSubview(finishBtn)
    }

    // MARK: - Step Indicator Dots

    private func addStepIndicator(to container: NSView) {
        let dotCount = totalSteps - 1 // Steps 1-5 (skip welcome)
        let dotSize: CGFloat = 8
        let dotSpacing: CGFloat = 12
        let totalWidth = CGFloat(dotCount) * dotSize + CGFloat(dotCount - 1) * dotSpacing
        let startX = (container.bounds.width - totalWidth) / 2
        let y: CGFloat = 30

        for i in 0..<dotCount {
            let dot = NSView(frame: NSRect(
                x: startX + CGFloat(i) * (dotSize + dotSpacing),
                y: y,
                width: dotSize, height: dotSize
            ))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = dotSize / 2

            let stepIndex = i + 1 // dot 0 = step 1, dot 1 = step 2, etc.
            if stepIndex == currentStep {
                dot.layer?.backgroundColor = accentColor.cgColor
            } else if stepIndex < currentStep {
                dot.layer?.backgroundColor = accentColor.withAlphaComponent(0.4).cgColor
            } else {
                dot.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.15).cgColor
            }

            dot.autoresizingMask = [.minXMargin, .maxXMargin]
            container.addSubview(dot)
        }
    }

    // MARK: - Navigation Buttons

    private func addNavigationButtons(to container: NSView, showBack: Bool) {
        let width = container.bounds.width
        let y: CGFloat = 60

        if showBack {
            let backBtn = makeSecondaryButton(title: "Back", target: self, action: #selector(prevStep))
            backBtn.frame = NSRect(x: 60, y: y, width: 100, height: 40)
            container.addSubview(backBtn)
        }

        let nextBtn = makeAmberButton(title: "Next", target: self, action: #selector(nextStep))
        nextBtn.frame = NSRect(x: width - 160, y: y, width: 100, height: 40)
        nextBtn.autoresizingMask = [.minXMargin]
        container.addSubview(nextBtn)
        self.nextButtonRef = nextBtn
    }

    // MARK: - UI Helpers

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }

    private func makeAmberButton(title: String, target: Any?, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = accentColor.cgColor
        button.layer?.cornerRadius = 12
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.black,
                .font: NSFont.systemFont(ofSize: 14, weight: .semibold)
            ]
        )
        return button
    }

    private func makeSecondaryButton(title: String, target: Any?, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.cornerRadius = 12
        button.layer?.borderWidth = 1
        button.layer?.borderColor = borderColor.cgColor
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: textColor,
                .font: NSFont.systemFont(ofSize: 14, weight: .medium)
            ]
        )
        return button
    }

    private func makeCard(frame: NSRect) -> NSView {
        let card = NSView(frame: frame)
        card.wantsLayer = true
        card.layer?.backgroundColor = cardBgColor.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = borderColor.cgColor
        card.autoresizingMask = [.width]
        return card
    }

    // MARK: - Permission Checks

    private func isMicrophoneGranted() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func isAccessibilityGranted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Permission Polling

    private func startAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if self.isAccessibilityGranted() {
                timer.invalidate()
                self.accessibilityPollTimer = nil
                self.updateAccessibilityStatus(granted: true)
                log("Accessibility permission granted via onboarding")
            }
        }
    }

    private func startMicrophonePolling() {
        microphonePollTimer?.invalidate()
        microphonePollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if self.isMicrophoneGranted() {
                timer.invalidate()
                self.microphonePollTimer = nil
                self.updateMicrophoneStatus(granted: true)
                log("Microphone permission granted via onboarding")
            }
        }
    }

    private func updateAccessibilityStatus(granted: Bool) {
        accessibilityStatusView?.layer?.backgroundColor = (granted ? greenColor : accentColor).cgColor
        accessibilityStatusLabel?.stringValue = granted ? "Permission Granted" : "Permission Needed"
        accessibilityStatusLabel?.textColor = granted ? greenColor : accentColor
        if granted {
            accessibilityActionButton?.isHidden = true
        }
    }

    private func updateMicrophoneStatus(granted: Bool) {
        microphoneStatusView?.layer?.backgroundColor = (granted ? greenColor : accentColor).cgColor
        microphoneStatusLabel?.stringValue = granted ? "Permission Granted" : "Permission Needed"
        microphoneStatusLabel?.textColor = granted ? greenColor : accentColor
        if granted {
            microphoneActionButton?.isHidden = true
        }
    }

    // MARK: - NSTextFieldDelegate (API Key Masking)

    func controlTextDidChange(_ obj: Notification) {
        guard !isUpdatingMask,
              let field = obj.object as? NSTextField,
              field === apiKeyTextField else { return }

        let newText = field.stringValue
        let cursorPos: Int = field.currentEditor()?.selectedRange.location ?? newText.count

        if newText.isEmpty {
            apiKeyValue = ""
            return
        }

        let bullet: Character = "\u{2022}"
        let hasBullets = newText.contains(bullet)
        let hasNonBullets = newText.contains(where: { $0 != bullet })

        if !hasBullets {
            // All new text (first entry, or select-all + paste)
            apiKeyValue = newText
        } else if hasNonBullets {
            // Mix of bullets and new chars (typed/pasted alongside existing masked text)
            let chars = Array(newText)
            let leadingBullets = chars.prefix(while: { $0 == bullet }).count
            let trailingBullets = Array(chars.reversed()).prefix(while: { $0 == bullet }).count
            let middleStart = leadingBullets
            let middleEnd = chars.count - trailingBullets
            let newChars = String(chars[middleStart..<middleEnd].filter { $0 != bullet })

            let prefix = String(apiKeyValue.prefix(leadingBullets))
            let suffix = String(apiKeyValue.suffix(trailingBullets))
            apiKeyValue = prefix + newChars + suffix
        } else {
            // All bullets but count changed — deletion
            let removedCount = apiKeyValue.count - newText.count
            if removedCount > 0 && cursorPos >= 0 && cursorPos + removedCount <= apiKeyValue.count {
                let startIdx = apiKeyValue.index(apiKeyValue.startIndex, offsetBy: cursorPos)
                let endIdx = apiKeyValue.index(startIdx, offsetBy: removedCount)
                apiKeyValue.removeSubrange(startIdx..<endIdx)
            } else if newText.count < apiKeyValue.count {
                apiKeyValue = String(apiKeyValue.prefix(newText.count))
            }
        }

        // Re-mask the field
        isUpdatingMask = true
        let masked = String(repeating: bullet, count: apiKeyValue.count)
        if let editor = field.currentEditor() as? NSTextView {
            editor.string = masked
            editor.setSelectedRange(NSRange(location: min(cursorPos, apiKeyValue.count), length: 0))
        } else {
            field.stringValue = masked
        }
        isUpdatingMask = false

        // Clear error when user types
        apiKeyErrorLabel?.isHidden = true
    }

    // MARK: - Actions

    @objc private func nextStep() {
        // Validate current step before advancing
        if currentStep == 4 {
            if !validateAPIKey() { return }
        }

        if currentStep < totalSteps - 1 {
            currentStep += 1
            buildStep()
        }
    }

    @objc private func prevStep() {
        if currentStep > 0 {
            currentStep -= 1
            buildStep()
        }
    }

    private func validateAPIKey() -> Bool {
        let key = apiKeyValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if !Config.hasAPIKey && key.isEmpty {
            apiKeyErrorLabel?.stringValue = "Please enter your OpenAI API key."
            apiKeyErrorLabel?.isHidden = false
            return false
        }

        if !key.isEmpty {
            if Config.saveAPIKey(key) {
                log("API key saved from welcome window")
            } else {
                apiKeyErrorLabel?.stringValue = "Failed to save API key. Check file permissions."
                apiKeyErrorLabel?.isHidden = false
                return false
            }
        }

        return true
    }

    @objc private func finishClicked() {
        // Clean up timers
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        microphonePollTimer?.invalidate()
        microphonePollTimer = nil

        // Enable launch at login by default
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                log("Launch at login enabled during onboarding")
            } catch {
                log("Launch at login error: \(error.localizedDescription)")
            }
        }

        window?.close()
        onComplete?()
    }

    @objc private func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func grantAccessibilityClicked() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let alreadyTrusted = AXIsProcessTrustedWithOptions(options)
        if alreadyTrusted {
            updateAccessibilityStatus(granted: true)
        }
    }

    @objc private func grantMicrophoneClicked() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.updateMicrophoneStatus(granted: true)
                        log("Microphone permission granted via onboarding")
                    }
                }
            }
        case .denied, .restricted:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        case .authorized:
            updateMicrophoneStatus(granted: true)
        @unknown default:
            break
        }
    }

    @objc private func openAPIKeyPage() {
        if let url = URL(string: "https://platform.openai.com/api-keys") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func copyPrompt() {
        let prompt = "Fork and clone https://github.com/beausterling/CustomWispr \u{2014} it\u{2019}s a macOS menu bar speech-to-text app built in Swift. Read the README and codebase, then help me customize it."
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)

        // Visual feedback: change button title briefly
        if let container = window?.contentView {
            for subview in container.subviews {
                for btn in subview.subviews where btn is NSButton {
                    if let button = btn as? NSButton,
                       button.attributedTitle.string == "Copy" || button.attributedTitle.string == "Copied!" {
                        button.attributedTitle = NSAttributedString(
                            string: "Copied!",
                            attributes: [
                                .foregroundColor: greenColor,
                                .font: NSFont.systemFont(ofSize: 11, weight: .medium)
                            ]
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            button.attributedTitle = NSAttributedString(
                                string: "Copy",
                                attributes: [
                                    .foregroundColor: self.textColor,
                                    .font: NSFont.systemFont(ofSize: 11, weight: .medium)
                                ]
                            )
                        }
                        break
                    }
                }
            }
        }
    }

    @objc private func openBuyMeACoffee() {
        if let url = URL(string: "https://buymeacoffee.com/beausterling") {
            NSWorkspace.shared.open(url)
        }
    }
}
