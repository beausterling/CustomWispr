import Cocoa

class SettingsWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var window: NSWindow?
    private var tableView: NSTableView?
    private var rows: [(find: String, replace: String)] = []

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        rows = SettingsManager.shared.replacements.map { ($0.find, $0.replace) }

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
        let titleLabel = NSTextField(labelWithString: "Find & Replace")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.frame = NSRect(x: 20, y: contentView.bounds.height - 40, width: 480, height: 22)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(titleLabel)

        // Subtitle label
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Fix words that are consistently mistranscribed. Replacements are applied after each transcription.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: contentView.bounds.height - 72, width: 480, height: 28)
        subtitleLabel.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(subtitleLabel)

        // Table view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: contentView.bounds.width - 40, height: contentView.bounds.height - 140))
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
        contentView.addSubview(scrollView)
        self.tableView = tableView

        // + button
        let addButton = NSButton(title: "+", target: self, action: #selector(addRow))
        addButton.bezelStyle = .rounded
        addButton.frame = NSRect(x: 20, y: 16, width: 32, height: 32)
        addButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        contentView.addSubview(addButton)

        // - button
        let removeButton = NSButton(title: "\u{2212}", target: self, action: #selector(removeRow))
        removeButton.bezelStyle = .rounded
        removeButton.frame = NSRect(x: 56, y: 16, width: 32, height: 32)
        removeButton.autoresizingMask = [.maxXMargin, .maxYMargin]
        contentView.addSubview(removeButton)

        // Save button
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.frame = NSRect(x: contentView.bounds.width - 100, y: 16, width: 80, height: 32)
        saveButton.autoresizingMask = [.minXMargin, .maxYMargin]
        contentView.addSubview(saveButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    // MARK: - Actions

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
