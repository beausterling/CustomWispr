import Cocoa

class KeyMonitor {
    var onFnKeyDown: (() -> Void)?
    var onFnKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
    private var fnIsDown = false

    private static let fnKeyCode: UInt16 = 63
    private static let fnFlagMask: UInt64 = 0x800000

    func start() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            log("ERROR: Failed to create event tap. Is Accessibility permission granted?")
            Unmanaged<KeyMonitor>.fromOpaque(selfPtr).release()
            return false
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Health check: re-enable tap if macOS disables it
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, let tap = self.eventTap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                log("Event tap was disabled, re-enabling...")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }

        log("Key monitor started successfully")
        return true
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // If the tap gets disabled, re-enable it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Only handle fn key (keyCode 63)
        guard keyCode == KeyMonitor.fnKeyCode else {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags.rawValue
        let fnPressed = (flags & KeyMonitor.fnFlagMask) != 0

        if fnPressed && !fnIsDown {
            fnIsDown = true
            DispatchQueue.main.async { [weak self] in
                self?.onFnKeyDown?()
            }
            return nil // Suppress the event
        } else if !fnPressed && fnIsDown {
            fnIsDown = false
            DispatchQueue.main.async { [weak self] in
                self?.onFnKeyUp?()
            }
            return nil // Suppress the event
        }

        return Unmanaged.passRetained(event)
    }
}
