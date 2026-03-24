import Cocoa
import QuartzCore

class OverlayWindow {
    private var panel: NSPanel?
    private var label: NSTextField?

    func show(status: String) {
        let work = { [self] in
            if panel == nil {
                createPanel()
            }
            label?.stringValue = status
            panel?.orderFrontRegardless()
            CATransaction.flush()  // render immediately, don't wait for next run loop
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    func hide() {
        if Thread.isMainThread {
            panel?.orderOut(nil)
        } else {
            DispatchQueue.main.async { [self] in
                panel?.orderOut(nil)
            }
        }
    }

    private func createPanel() {
        guard let screen = NSScreen.main else { return }

        let pillWidth: CGFloat = 200
        let pillHeight: CGFloat = 40
        let bottomMargin: CGFloat = 100

        let x = (screen.frame.width - pillWidth) / 2
        let y = bottomMargin
        let frame = NSRect(x: x, y: y, width: pillWidth, height: pillHeight)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true

        // Background view with rounded corners
        let bgView = NSView(frame: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight))
        bgView.wantsLayer = true
        bgView.layer?.cornerRadius = pillHeight / 2
        bgView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.85).cgColor
        panel.contentView = bgView

        // Status label — centered with Auto Layout
        let label = NSTextField(labelWithString: "")
        label.isEditable = false
        label.isBordered = false
        label.isSelectable = false
        label.backgroundColor = .clear
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: bgView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: bgView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: bgView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: bgView.trailingAnchor, constant: -16),
        ])

        self.panel = panel
        self.label = label
    }

    // These ensure the panel never steals focus
    var canBecomeKey: Bool { false }
    var canBecomeMain: Bool { false }
}
