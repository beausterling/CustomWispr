import Cocoa
import ServiceManagement

class SettingsWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private var window: NSWindow?
    private var tableView: NSTableView?
    private var rows: [(find: String, replace: String)] = []
    private var apiKeyField: NSTextField?
    private var apiKeyStatusLabel: NSTextField?
    private var loginCheckbox: NSButton?

    // API key masking
    private var apiKeyValue = ""
    private var isUpdatingMask = false

    // Custom tab bar
    private var currentTab = 0
    private var tabButtons: [NSButton] = []
    private var tabUnderlines: [NSView] = []
    private var contentContainer: NSView?

    // MARK: - Colors (matching customwispr-site)

    private let bgColor = NSColor(red: 0x0e/255.0, green: 0x0e/255.0, blue: 0x10/255.0, alpha: 1.0)
    private let textColor = NSColor(red: 0xe8/255.0, green: 0xe6/255.0, blue: 0xe3/255.0, alpha: 1.0)
    private let mutedColor = NSColor(red: 0x94/255.0, green: 0x92/255.0, blue: 0x9d/255.0, alpha: 1.0)
    private let accentColor = NSColor(red: 0xf5/255.0, green: 0x9e/255.0, blue: 0x0b/255.0, alpha: 1.0)
    private let borderColor = NSColor(white: 1.0, alpha: 0.08)
    private let cardBgColor = NSColor(white: 1.0, alpha: 0.03)
    private let greenColor = NSColor(red: 0x22/255.0, green: 0xc5/255.0, blue: 0x5e/255.0, alpha: 1.0)

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        rows = SettingsManager.shared.replacements.map { ($0.find, $0.replace) }
        apiKeyValue = ""

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = bgColor
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = bgColor.cgColor

        // Reset to first tab before building UI
        currentTab = 0

        // Build custom tab bar
        buildTabBar(in: contentView)

        // Build content container
        let container = NSView(frame: NSRect(x: 0, y: 0, width: contentView.bounds.width, height: contentView.bounds.height - 44))
        container.autoresizingMask = [.width, .height]
        contentView.addSubview(container)
        self.contentContainer = container

        window.contentView = contentView
        showTab(currentTab)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    // MARK: - Custom Tab Bar

    private func buildTabBar(in parent: NSView) {
        let tabBarHeight: CGFloat = 44
        let width = parent.bounds.width
        let tabBar = NSView(frame: NSRect(x: 0, y: parent.bounds.height - tabBarHeight, width: width, height: tabBarHeight))
        tabBar.autoresizingMask = [.width, .minYMargin]
        tabBar.wantsLayer = true

        // Bottom border for tab bar
        let separator = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        separator.wantsLayer = true
        separator.layer?.backgroundColor = borderColor.cgColor
        separator.autoresizingMask = [.width]
        tabBar.addSubview(separator)

        let tabTitles = ["API Key", "Find & Replace", "Customize"]
        let tabWidth = width / CGFloat(tabTitles.count)

        tabButtons = []
        tabUnderlines = []

        for (i, title) in tabTitles.enumerated() {
            let button = NSButton(title: title, target: self, action: #selector(tabClicked(_:)))
            button.tag = i
            button.isBordered = false
            button.wantsLayer = true
            button.frame = NSRect(x: CGFloat(i) * tabWidth, y: 4, width: tabWidth, height: tabBarHeight - 6)
            button.autoresizingMask = i == tabTitles.count - 1 ? [.minXMargin, .width] : (i == 0 ? [.maxXMargin, .width] : [.width])
            tabBar.addSubview(button)
            tabButtons.append(button)

            // Underline indicator
            let underline = NSView(frame: NSRect(x: CGFloat(i) * tabWidth + 10, y: 1, width: tabWidth - 20, height: 2))
            underline.wantsLayer = true
            underline.layer?.cornerRadius = 1
            underline.autoresizingMask = button.autoresizingMask
            tabBar.addSubview(underline)
            tabUnderlines.append(underline)
        }

        parent.addSubview(tabBar)
        updateTabAppearance()
    }

    private func updateTabAppearance() {
        for (i, button) in tabButtons.enumerated() {
            let isActive = i == currentTab
            let color = isActive ? accentColor : mutedColor
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.systemFont(ofSize: 13, weight: isActive ? .semibold : .medium)
                ]
            )
            tabUnderlines[i].layer?.backgroundColor = isActive ? accentColor.cgColor : NSColor.clear.cgColor
        }
    }

    @objc private func tabClicked(_ sender: NSButton) {
        currentTab = sender.tag
        updateTabAppearance()
        showTab(currentTab)
    }

    private func showTab(_ index: Int) {
        guard let container = contentContainer else { return }
        container.subviews.forEach { $0.removeFromSuperview() }

        let width = container.bounds.width
        let height = container.bounds.height

        switch index {
        case 0: container.addSubview(buildAPIKeyTab(width: width, height: height))
        case 1: container.addSubview(buildFindReplaceTab(width: width, height: height))
        case 2: container.addSubview(buildCustomizeTab(width: width, height: height))
        default: break
        }
    }

    // MARK: - Tab 1: API Key

    private func buildAPIKeyTab(width: CGFloat, height: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var y = height - 30

        let titleLabel = makeLabel("OpenAI API Key", size: 18, weight: .bold, color: textColor)
        titleLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 24)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(titleLabel)
        y -= 28

        let statusLabel = makeLabel(
            Config.hasAPIKey ? "Status: Configured" : "Status: Not configured",
            size: 12, weight: .medium,
            color: Config.hasAPIKey ? greenColor : accentColor
        )
        statusLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 18)
        statusLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(statusLabel)
        self.apiKeyStatusLabel = statusLabel
        y -= 36

        let fieldLabel = makeLabel("Enter a new API key to update:", size: 13, weight: .regular, color: mutedColor)
        fieldLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 18)
        fieldLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(fieldLabel)
        y -= 34

        // Regular NSTextField with bullet masking
        let keyField = NSTextField()
        keyField.placeholderString = "sk-..."
        keyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        keyField.frame = NSRect(x: 20, y: y, width: width - 40, height: 32)
        keyField.autoresizingMask = [.width, .minYMargin]
        keyField.usesSingleLineMode = true
        keyField.cell?.wraps = false
        keyField.cell?.isScrollable = true
        keyField.cell?.lineBreakMode = .byTruncatingTail
        keyField.maximumNumberOfLines = 1
        keyField.wantsLayer = true
        keyField.layer?.cornerRadius = 8
        keyField.layer?.borderWidth = 1
        keyField.layer?.borderColor = borderColor.cgColor
        keyField.backgroundColor = NSColor(white: 1.0, alpha: 0.05)
        keyField.textColor = textColor
        keyField.focusRingType = .none
        keyField.delegate = self
        view.addSubview(keyField)
        self.apiKeyField = keyField
        y -= 44

        let saveButton = makeAmberButton(title: "Save API Key", target: self, action: #selector(saveAPIKeyClicked))
        saveButton.frame = NSRect(x: 20, y: y, width: 140, height: 36)
        saveButton.autoresizingMask = [.maxXMargin, .minYMargin]
        view.addSubview(saveButton)
        y -= 50

        // Divider
        let divider = NSView(frame: NSRect(x: 20, y: y + 14, width: width - 40, height: 1))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = borderColor.cgColor
        divider.autoresizingMask = [.width, .minYMargin]
        view.addSubview(divider)

        // Launch at Login
        let loginCheckbox = NSButton(checkboxWithTitle: "Launch CustomWispr at login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        loginCheckbox.attributedTitle = NSAttributedString(
            string: "Launch CustomWispr at login",
            attributes: [
                .foregroundColor: textColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
        )
        loginCheckbox.frame = NSRect(x: 20, y: y - 10, width: width - 40, height: 20)
        loginCheckbox.autoresizingMask = [.width, .minYMargin]
        if #available(macOS 13.0, *) {
            loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
        view.addSubview(loginCheckbox)
        self.loginCheckbox = loginCheckbox

        return view
    }

    @objc private func saveAPIKeyClicked() {
        let key = apiKeyValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        if Config.saveAPIKey(key) {
            log("API key updated from settings")
            apiKeyValue = ""
            apiKeyField?.stringValue = ""
            apiKeyStatusLabel?.stringValue = "Status: Configured"
            apiKeyStatusLabel?.textColor = greenColor
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if sender.state == .on {
                    try service.register()
                    log("Launch at login enabled")
                } else {
                    try service.unregister()
                    log("Launch at login disabled")
                }
            } catch {
                log("Launch at login error: \(error.localizedDescription)")
                sender.state = sender.state == .on ? .off : .on
            }
        }
    }

    // MARK: - NSTextFieldDelegate (API Key Masking)

    func controlTextDidChange(_ obj: Notification) {
        guard !isUpdatingMask,
              let field = obj.object as? NSTextField,
              field === apiKeyField else { return }

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
            apiKeyValue = newText
        } else if hasNonBullets {
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
            let removedCount = apiKeyValue.count - newText.count
            if removedCount > 0 && cursorPos >= 0 && cursorPos + removedCount <= apiKeyValue.count {
                let startIdx = apiKeyValue.index(apiKeyValue.startIndex, offsetBy: cursorPos)
                let endIdx = apiKeyValue.index(startIdx, offsetBy: removedCount)
                apiKeyValue.removeSubrange(startIdx..<endIdx)
            } else if newText.count < apiKeyValue.count {
                apiKeyValue = String(apiKeyValue.prefix(newText.count))
            }
        }

        isUpdatingMask = true
        let masked = String(repeating: bullet, count: apiKeyValue.count)
        if let editor = field.currentEditor() as? NSTextView {
            editor.string = masked
            editor.setSelectedRange(NSRange(location: min(cursorPos, apiKeyValue.count), length: 0))
        } else {
            field.stringValue = masked
        }
        isUpdatingMask = false
    }

    // MARK: - Tab 2: Find & Replace

    private func buildFindReplaceTab(width: CGFloat, height: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var y = height - 30

        let titleLabel = makeLabel("Find & Replace", size: 18, weight: .bold, color: textColor)
        titleLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 24)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(titleLabel)
        y -= 26

        let subtitleLabel = NSTextField(wrappingLabelWithString: "Fix words that are consistently mistranscribed. Replacements are applied after each transcription.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = mutedColor
        subtitleLabel.backgroundColor = .clear
        subtitleLabel.isBordered = false
        subtitleLabel.isEditable = false
        subtitleLabel.frame = NSRect(x: 20, y: y - 14, width: width - 40, height: 28)
        subtitleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(subtitleLabel)
        y -= 48

        // Table in a card container
        let cardFrame = NSRect(x: 20, y: 56, width: width - 40, height: y - 56)
        let card = NSView(frame: cardFrame)
        card.wantsLayer = true
        card.layer?.backgroundColor = cardBgColor.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = borderColor.cgColor
        card.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView(frame: NSRect(x: 1, y: 1, width: cardFrame.width - 2, height: cardFrame.height - 2))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 24
        tableView.gridColor = borderColor
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]

        let findColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("find"))
        findColumn.title = "Find"
        findColumn.isEditable = true
        findColumn.minWidth = 120
        findColumn.headerCell.textColor = textColor
        tableView.addTableColumn(findColumn)

        let replaceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("replace"))
        replaceColumn.title = "Replace With"
        replaceColumn.isEditable = true
        replaceColumn.minWidth = 120
        replaceColumn.headerCell.textColor = textColor
        tableView.addTableColumn(replaceColumn)

        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        card.addSubview(scrollView)
        view.addSubview(card)
        self.tableView = tableView

        // + button
        let addButton = makeSecondaryButton(title: "+", target: self, action: #selector(addRow))
        addButton.frame = NSRect(x: 20, y: 14, width: 36, height: 32)
        addButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        view.addSubview(addButton)

        // - button
        let removeButton = makeSecondaryButton(title: "\u{2212}", target: self, action: #selector(removeRow))
        removeButton.frame = NSRect(x: 62, y: 14, width: 36, height: 32)
        removeButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        view.addSubview(removeButton)

        // Save button
        let saveButton = makeAmberButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.frame = NSRect(x: width - 100, y: 14, width: 80, height: 36)
        saveButton.autoresizingMask = [.minXMargin, .maxYMargin]
        view.addSubview(saveButton)

        return view
    }

    // MARK: - Tab 3: Customize

    private func buildCustomizeTab(width: CGFloat, height: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var y = height - 30

        let titleLabel = makeLabel("Customize CustomWispr", size: 18, weight: .bold, color: textColor)
        titleLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 24)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(titleLabel)
        y -= 26

        let descLabel = NSTextField(wrappingLabelWithString: "Copy the prompt below into any coding agent (Claude Code, Cursor, etc.) to fork and customize this app.")
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = mutedColor
        descLabel.backgroundColor = .clear
        descLabel.isBordered = false
        descLabel.isEditable = false
        descLabel.frame = NSRect(x: 20, y: y - 14, width: width - 40, height: 32)
        descLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(descLabel)
        y -= 52

        // Prompt text view in card container
        let cardFrame = NSRect(x: 20, y: 80, width: width - 40, height: y - 80)
        let card = NSView(frame: cardFrame)
        card.wantsLayer = true
        card.layer?.backgroundColor = cardBgColor.cgColor
        card.layer?.cornerRadius = 12
        card.layer?.borderWidth = 1
        card.layer?.borderColor = borderColor.cgColor
        card.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView(frame: NSRect(x: 1, y: 1, width: cardFrame.width - 2, height: cardFrame.height - 2))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: cardFrame.width - 6, height: cardFrame.height - 2))
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .clear
        textView.textColor = textColor
        textView.string = customizePrompt
        scrollView.documentView = textView
        card.addSubview(scrollView)
        view.addSubview(card)

        // Copy to Clipboard button
        let copyButton = makeAmberButton(title: "Copy to Clipboard", target: self, action: #selector(copyPromptClicked))
        copyButton.frame = NSRect(x: 20, y: 14, width: 160, height: 36)
        copyButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        view.addSubview(copyButton)

        // View on GitHub button
        let ghButton = makeSecondaryButton(title: "View on GitHub", target: self, action: #selector(openGitHubClicked))
        ghButton.frame = NSRect(x: 190, y: 14, width: 130, height: 36)
        ghButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        view.addSubview(ghButton)

        // Buy Me a Coffee link
        let coffeeButton = NSButton(title: "Buy Me a Coffee \u{2615}", target: self, action: #selector(openBuyMeACoffee))
        coffeeButton.isBordered = false
        coffeeButton.attributedTitle = NSAttributedString(
            string: "Buy Me a Coffee \u{2615}",
            attributes: [
                .foregroundColor: accentColor,
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        coffeeButton.frame = NSRect(x: width - 170, y: 18, width: 150, height: 20)
        coffeeButton.autoresizingMask = [.minXMargin, .maxYMargin]
        view.addSubview(coffeeButton)

        return view
    }

    private var customizePrompt: String {
        return """
        Clone and customize CustomWispr — a macOS menu bar speech-to-text app.

        GitHub: https://github.com/beausterling/CustomWispr

        Key files:
        - Sources/Config.swift          — API key loading and app configuration
        - Sources/AppDelegate.swift     — App lifecycle, menu bar, recording flow
        - Sources/AudioRecorder.swift   — Microphone recording to file
        - Sources/WhisperService.swift   — OpenAI Whisper transcription API
        - Sources/AICleanupService.swift — GPT post-processing of transcriptions
        - Sources/TextInjector.swift     — Pastes text into the active app
        - Sources/KeyMonitor.swift       — Global fn key listener (CGEventTap)
        - Sources/SettingsWindow.swift   — Settings UI with find/replace
        - Sources/SettingsManager.swift  — Persists user settings to disk
        - Sources/OverlayWindow.swift    — Recording status overlay
        - Sources/WelcomeWindow.swift    — First-run onboarding
        - Resources/Info.plist           — App bundle metadata
        - Resources/entitlements.plist   — macOS permissions
        - build-arm64.sh                 — Build for Apple Silicon
        - build.sh                       — Build for Intel
        - build-universal.sh             — Universal binary + DMG

        Build: ./build-arm64.sh (or ./build-universal.sh for distribution)
        Run:   open CustomWispr.app

        My customization request:
        [Describe what you want to change here]
        """
    }

    @objc private func copyPromptClicked() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(customizePrompt, forType: .string)
    }

    @objc private func openGitHubClicked() {
        if let url = URL(string: "https://github.com/beausterling/CustomWispr") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openBuyMeACoffee() {
        if let url = URL(string: "https://buymeacoffee.com/beausterling") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Find & Replace Actions

    /// End any active cell editing and read ALL visible cell values back into `rows`.
    /// Must be called before any operation that reads or mutates `rows`.
    private func syncRowsFromTable() {
        guard let tableView = tableView else { return }
        // End field editor — commits typed text back into the NSTextField's stringValue
        window?.makeFirstResponder(nil)
        // Read every visible cell back into the rows array
        for row in 0..<rows.count {
            if let findCell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? NSTableCellView,
               let findField = findCell.textField {
                rows[row].find = findField.stringValue
            }
            if let replaceCell = tableView.view(atColumn: 1, row: row, makeIfNecessary: false) as? NSTableCellView,
               let replaceField = replaceCell.textField {
                rows[row].replace = replaceField.stringValue
            }
        }
    }

    @objc private func addRow() {
        syncRowsFromTable()
        rows.append((find: "", replace: ""))
        tableView?.reloadData()
        let newRow = rows.count - 1
        tableView?.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView?.editColumn(0, row: newRow, with: nil, select: true)
    }

    @objc private func removeRow() {
        guard let tableView = tableView else { return }
        syncRowsFromTable()
        let selected = tableView.selectedRow
        guard selected >= 0 else { return }
        rows.remove(at: selected)
        tableView.reloadData()
    }

    @objc private func saveClicked() {
        syncRowsFromTable()
        let filtered = rows.filter { !$0.find.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        SettingsManager.shared.replacements = filtered.map { Replacement(find: $0.find, replace: $0.replace) }
        log("Settings saved (\(filtered.count) replacement\(filtered.count == 1 ? "" : "s"))")
        window?.close()
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return rows.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        let identifier = column.identifier

        let cellView: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cellView = existing
        } else {
            let textField = NSTextField()
            textField.isBordered = false
            textField.drawsBackground = false
            textField.isEditable = true
            textField.font = NSFont.systemFont(ofSize: 13)
            textField.textColor = textColor
            textField.lineBreakMode = .byTruncatingTail
            textField.target = self
            textField.action = #selector(textFieldEdited(_:))

            let cell = NSTableCellView()
            cell.identifier = identifier
            cell.textField = textField
            cell.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            cellView = cell
        }

        let value: String
        if identifier.rawValue == "find" {
            value = rows[row].find
        } else {
            value = rows[row].replace
        }
        cellView.textField?.stringValue = value

        return cellView
    }

    @objc private func textFieldEdited(_ sender: NSTextField) {
        guard let tableView = tableView else { return }
        let row = tableView.row(for: sender)
        let col = tableView.column(for: sender)
        guard row >= 0, col >= 0 else { return }
        let colID = tableView.tableColumns[col].identifier.rawValue
        if colID == "find" {
            rows[row].find = sender.stringValue
        } else {
            rows[row].replace = sender.stringValue
        }
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
}
