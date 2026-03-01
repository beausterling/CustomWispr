import Cocoa
import ServiceManagement

class SettingsWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTabViewDelegate {
    private var window: NSWindow?
    private var tableView: NSTableView?
    private var rows: [(find: String, replace: String)] = []
    private var apiKeyField: NSSecureTextField?
    private var apiKeyStatusLabel: NSTextField?
    private var loginCheckbox: NSButton?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        rows = SettingsManager.shared.replacements.map { ($0.find, $0.replace) }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.minSize = NSSize(width: 460, height: 360)

        let tabView = NSTabView(frame: window.contentView!.bounds)
        tabView.autoresizingMask = [.width, .height]
        tabView.delegate = self

        // Tab 1: API Key
        let apiKeyTab = NSTabViewItem(identifier: "apikey")
        apiKeyTab.label = "API Key"
        apiKeyTab.view = buildAPIKeyTab(width: 520, height: 380)
        tabView.addTabViewItem(apiKeyTab)

        // Tab 2: Find & Replace
        let findReplaceTab = NSTabViewItem(identifier: "findreplace")
        findReplaceTab.label = "Find & Replace"
        findReplaceTab.view = buildFindReplaceTab(width: 520, height: 380)
        tabView.addTabViewItem(findReplaceTab)

        // Tab 3: Customize
        let customizeTab = NSTabViewItem(identifier: "customize")
        customizeTab.label = "Customize"
        customizeTab.view = buildCustomizeTab(width: 520, height: 380)
        tabView.addTabViewItem(customizeTab)

        window.contentView = tabView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    // MARK: - Tab 1: API Key

    private func buildAPIKeyTab(width: CGFloat, height: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var y = height - 30

        let titleLabel = NSTextField(labelWithString: "OpenAI API Key")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 22)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(titleLabel)
        y -= 28

        let statusLabel = NSTextField(labelWithString: Config.hasAPIKey ? "Status: Configured" : "Status: Not configured")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = Config.hasAPIKey ? .systemGreen : .systemOrange
        statusLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 18)
        statusLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(statusLabel)
        self.apiKeyStatusLabel = statusLabel
        y -= 36

        let fieldLabel = NSTextField(labelWithString: "Enter a new API key to update:")
        fieldLabel.font = NSFont.systemFont(ofSize: 13)
        fieldLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 18)
        fieldLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(fieldLabel)
        y -= 30

        let keyField = NSSecureTextField()
        keyField.placeholderString = "sk-..."
        keyField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        keyField.frame = NSRect(x: 20, y: y, width: width - 40, height: 28)
        keyField.autoresizingMask = [.width, .minYMargin]
        view.addSubview(keyField)
        self.apiKeyField = keyField
        y -= 40

        let saveButton = NSButton(title: "Save API Key", target: self, action: #selector(saveAPIKeyClicked))
        saveButton.bezelStyle = .rounded
        saveButton.frame = NSRect(x: 20, y: y, width: 120, height: 32)
        saveButton.autoresizingMask = [.maxXMargin, .minYMargin]
        view.addSubview(saveButton)
        y -= 50

        // Launch at Login
        let divider = NSBox()
        divider.boxType = .separator
        divider.frame = NSRect(x: 20, y: y + 14, width: width - 40, height: 1)
        divider.autoresizingMask = [.width, .minYMargin]
        view.addSubview(divider)

        let loginCheckbox = NSButton(checkboxWithTitle: "Launch CustomWispr at login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        loginCheckbox.font = NSFont.systemFont(ofSize: 13)
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
        guard let keyField = apiKeyField else { return }
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        if Config.saveAPIKey(key) {
            log("API key updated from settings")
            keyField.stringValue = ""
            apiKeyStatusLabel?.stringValue = "Status: Configured"
            apiKeyStatusLabel?.textColor = .systemGreen
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
                // Revert checkbox state on failure
                sender.state = sender.state == .on ? .off : .on
            }
        }
    }

    // MARK: - Tab 2: Find & Replace

    private func buildFindReplaceTab(width: CGFloat, height: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var y = height - 30

        let titleLabel = NSTextField(labelWithString: "Find & Replace")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 22)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(titleLabel)
        y -= 28

        let subtitleLabel = NSTextField(wrappingLabelWithString: "Fix words that are consistently mistranscribed. Replacements are applied after each transcription.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: y - 10, width: width - 40, height: 28)
        subtitleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(subtitleLabel)
        y -= 48

        // Table view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 56, width: width - 40, height: y - 56))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 24

        let findColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("find"))
        findColumn.title = "Find"
        findColumn.isEditable = true
        findColumn.minWidth = 120
        tableView.addTableColumn(findColumn)

        let replaceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("replace"))
        replaceColumn.title = "Replace With"
        replaceColumn.isEditable = true
        replaceColumn.minWidth = 120
        tableView.addTableColumn(replaceColumn)

        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        view.addSubview(scrollView)
        self.tableView = tableView

        // + button
        let addButton = NSButton(title: "+", target: self, action: #selector(addRow))
        addButton.bezelStyle = .rounded
        addButton.frame = NSRect(x: 20, y: 16, width: 32, height: 32)
        addButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        view.addSubview(addButton)

        // - button
        let removeButton = NSButton(title: "\u{2212}", target: self, action: #selector(removeRow))
        removeButton.bezelStyle = .rounded
        removeButton.frame = NSRect(x: 56, y: 16, width: 32, height: 32)
        removeButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        view.addSubview(removeButton)

        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: width - 100, y: 16, width: 80, height: 32)
        saveButton.autoresizingMask = [.minXMargin, .maxYMargin]
        view.addSubview(saveButton)

        return view
    }

    // MARK: - Tab 3: Customize

    private func buildCustomizeTab(width: CGFloat, height: CGFloat) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var y = height - 30

        let titleLabel = NSTextField(labelWithString: "Customize CustomWispr")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: y, width: width - 40, height: 22)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(titleLabel)
        y -= 28

        let descLabel = NSTextField(wrappingLabelWithString: "Copy the prompt below into any coding agent (Claude Code, Cursor, etc.) to fork and customize this app.")
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 20, y: y - 10, width: width - 40, height: 32)
        descLabel.autoresizingMask = [.width, .minYMargin]
        view.addSubview(descLabel)
        y -= 48

        // Prompt text view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 56, width: width - 40, height: y - 56))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width - 44, height: y - 56))
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        textView.string = customizePrompt
        scrollView.documentView = textView
        view.addSubview(scrollView)

        // Copy button
        let copyButton = NSButton(title: "Copy to Clipboard", target: self, action: #selector(copyPromptClicked))
        copyButton.bezelStyle = .rounded
        copyButton.frame = NSRect(x: 20, y: 16, width: 140, height: 32)
        copyButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        view.addSubview(copyButton)

        // GitHub button
        let ghButton = NSButton(title: "View on GitHub", target: self, action: #selector(openGitHubClicked))
        ghButton.bezelStyle = .rounded
        ghButton.frame = NSRect(x: width - 140, y: 16, width: 120, height: 32)
        ghButton.autoresizingMask = [.minXMargin, .maxYMargin]
        view.addSubview(ghButton)

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

    // MARK: - Find & Replace Actions

    @objc private func addRow() {
        rows.append((find: "", replace: ""))
        tableView?.reloadData()
        let newRow = rows.count - 1
        tableView?.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView?.editColumn(0, row: newRow, with: nil, select: true)
    }

    @objc private func removeRow() {
        guard let tableView = tableView else { return }
        let selected = tableView.selectedRow
        guard selected >= 0 else { return }
        rows.remove(at: selected)
        tableView.reloadData()
    }

    @objc private func saveClicked() {
        commitEditing()
        let filtered = rows.filter { !$0.find.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        SettingsManager.shared.replacements = filtered.map { Replacement(find: $0.find, replace: $0.replace) }
        log("Settings saved (\(filtered.count) replacement\(filtered.count == 1 ? "" : "s"))")
        window?.close()
    }

    private func commitEditing() {
        guard let tableView = tableView else { return }
        let editedRow = tableView.editedRow
        let editedCol = tableView.editedColumn
        if editedRow >= 0, editedCol >= 0,
           let cellView = tableView.view(atColumn: editedCol, row: editedRow, makeIfNecessary: false) as? NSTableCellView,
           let textField = cellView.textField {
            let value = textField.stringValue
            let colID = tableView.tableColumns[editedCol].identifier.rawValue
            if colID == "find" {
                rows[editedRow].find = value
            } else {
                rows[editedRow].replace = value
            }
        }
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
}
