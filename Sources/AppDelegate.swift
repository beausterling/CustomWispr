import Cocoa
import AVFoundation

func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    fputs("[\(timestamp)] CustomWispr: \(message)\n", stderr)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let overlay = OverlayWindow()
    private let recorder = AudioRecorder()
    private let whisper = WhisperService()
    private let cleanup = AICleanupService()
    private let injector = TextInjector()
    private let keyMonitor = KeyMonitor()

    private let settingsWindow = SettingsWindow()

    private var isRecording = false
    private var isProcessing = false
    private var maxRecordingTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 300 // 5 minutes

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("App launched")
        AudioRecorder.cleanupStaleFiles()
        setupMenuBar()
        requestPermissions()
        startKeyMonitor()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "W"
            button.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "CustomWispr", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        log("Menu bar setup complete")
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func quit() {
        keyMonitor.stop()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Permissions

    private func requestPermissions() {
        // Request microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            log("Requesting microphone permission...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                log("Microphone permission \(granted ? "granted" : "denied")")
            }
        case .denied, .restricted:
            log("ERROR: Microphone permission denied. Grant in System Settings > Privacy & Security > Microphone")
        case .authorized:
            log("Microphone permission already granted")
        @unknown default:
            break
        }

        // Check accessibility (needed for CGEventTap)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        log("Accessibility trusted: \(trusted)")
    }

    // MARK: - Key Monitor

    private func startKeyMonitor() {
        keyMonitor.onFnKeyDown = { [weak self] in
            log("fn key DOWN detected")
            self?.handleFnDown()
        }
        keyMonitor.onFnKeyUp = { [weak self] in
            log("fn key UP detected")
            self?.handleFnUp()
        }

        if keyMonitor.start() {
            log("Key monitor started successfully")
        } else {
            log("ERROR: Failed to start key monitor. Check Accessibility permissions.")
        }
    }

    // MARK: - Recording Flow

    private func handleFnDown() {
        guard !isRecording && !isProcessing else {
            log("Ignoring fn down (recording=\(isRecording), processing=\(isProcessing))")
            return
        }
        isRecording = true

        do {
            _ = try recorder.startRecording()
            overlay.show(status: "Listening...")
            log("Recording started")

            maxRecordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
                log("Max recording duration reached (5 min), auto-stopping")
                self?.handleFnUp()
            }
        } catch {
            log("ERROR: Failed to start recording: \(error.localizedDescription)")
            isRecording = false
        }
    }

    private func handleFnUp() {
        guard isRecording else { return }
        isRecording = false
        isProcessing = true
        maxRecordingTimer?.invalidate()
        maxRecordingTimer = nil

        guard let audioURL = recorder.stopRecording() else {
            log("ERROR: No audio file after stopping recording")
            isProcessing = false
            overlay.hide()
            return
        }

        overlay.show(status: "Processing...")
        log("Recording stopped, processing...")

        Task {
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.isProcessing = false
                    self?.overlay.hide()
                    self?.recorder.cleanup()
                }
            }

            do {
                // Step 1: Transcribe
                let rawText = try await whisper.transcribe(audioFileURL: audioURL)
                #if DEBUG
                log("Transcribed: \(rawText.prefix(100))...")
                #endif

                guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    log("Empty transcription, skipping")
                    return
                }

                // Step 2: Clean up with AI
                let cleanedText = await cleanup.cleanup(rawText: rawText)
                #if DEBUG
                log("Cleaned: \(cleanedText.prefix(100))...")
                #endif

                // Step 3: Inject into active text field
                DispatchQueue.main.async { [weak self] in
                    self?.injector.inject(text: cleanedText)
                    log("Text injected successfully")
                }
            } catch {
                log("ERROR: Processing failed: \(error.localizedDescription)")
            }
        }
    }
}
