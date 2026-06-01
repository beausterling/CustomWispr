import AVFoundation
import CoreAudio
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?
    private var framesWritten: AVAudioFramePosition = 0

    func startRecording() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("custom-wispr_\(UUID().uuidString).m4a")
        self.tempFileURL = fileURL
        self.framesWritten = 0

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Pin recording to the user's chosen input device (Settings > Microphone),
        // ignoring the macOS system default. Bluetooth headsets (AirPods, etc.)
        // auto-grab the default input when they connect but often deliver
        // empty/garbled audio to AVAudioEngine, which silently produced empty
        // files. Pinning to an explicit device makes dictation reliable no matter
        // what headphones connect. Falls back to the built-in mic.
        if let deviceID = AudioRecorder.preferredInputDeviceID(),
           let audioUnit = inputNode.audioUnit {
            var dev = deviceID
            let err = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &dev,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if err == noErr {
                log("Pinned recording to input device \(deviceID) (\(AudioRecorder.deviceName(deviceID) ?? "unknown"))")
            } else {
                log("WARNING: Could not pin to selected mic (OSStatus \(err)); using system default input")
            }
        } else {
            log("WARNING: No usable input device found; using system default input")
        }

        // Use outputFormat (not inputFormat) to avoid crashes on some hardware.
        // This is the device's *actual* delivered format — record it as-is.
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw RecorderError.noMicrophone
        }

        // Record at the mic's native sample rate / channel count straight to AAC.
        // AVAudioFile handles PCM→AAC encoding internally, so there's no fragile
        // in-tap sample-rate conversion to silently drop frames. AAC is pinned at
        // 32 kbps regardless of sample rate, so the upload stays small either way,
        // and Whisper happily accepts any sample rate.
        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: recordingFormat.sampleRate,
                AVNumberOfChannelsKey: min(recordingFormat.channelCount, 2),
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
                AVEncoderBitRateKey: 32000
            ]
        )

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            do {
                try audioFile.write(from: buffer)
                self?.framesWritten += AVAudioFramePosition(buffer.frameLength)
            } catch {
                log("ERROR: Failed to write audio buffer: \(error.localizedDescription)")
            }
        }

        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        self.audioFile = audioFile

        return fileURL
    }

    func stopRecording() -> URL? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil  // finalizes/closes the AAC file
        log("Recording stopped: \(framesWritten) frames captured")
        if framesWritten == 0 {
            log("WARNING: No audio frames were captured — check the default input device.")
        }
        return tempFileURL
    }

    func cleanup() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }

    // MARK: - Device selection

    /// Find the AudioDeviceID of the Mac's built-in microphone (transport type
    /// "built-in" with at least one input channel). Returns nil if none exists.
    static func builtInInputDeviceID() -> AudioDeviceID? {
        var listAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &listAddr, 0, nil, &dataSize
        ) == noErr else { return nil }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return nil }

        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &listAddr, 0, nil, &dataSize, &devices
        ) == noErr else { return nil }

        for device in devices where deviceHasInput(device) {
            var transport: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &transport) == noErr,
               transport == kAudioDeviceTransportTypeBuiltIn {
                return device
            }
        }
        return nil
    }

    /// Whether a device exposes at least one input channel.
    private static func deviceHasInput(_ device: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &addr, 0, nil, &size) == noErr, size > 0 else {
            return false
        }

        let bufList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufList.deallocate() }

        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, bufList) == noErr else {
            return false
        }

        let abl = UnsafeMutableAudioBufferListPointer(
            bufList.assumingMemoryBound(to: AudioBufferList.self)
        )
        for buffer in abl where buffer.mNumberChannels > 0 {
            return true
        }
        return false
    }

    /// A selectable input device (microphone).
    struct InputDevice {
        let id: AudioDeviceID
        let uid: String   // stable across reconnects/reboots — used for persistence
        let name: String
    }

    /// All currently-connected input devices, in system order.
    static func availableInputDevices() -> [InputDevice] {
        var listAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &listAddr, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }

        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &listAddr, 0, nil, &dataSize, &devices
        ) == noErr else { return [] }

        return devices.compactMap { device -> InputDevice? in
            guard deviceHasInput(device),
                  let uid = deviceUID(device),
                  let name = deviceName(device) else { return nil }
            return InputDevice(id: device, uid: uid, name: name)
        }
    }

    /// Resolve a stored device UID to a currently-connected AudioDeviceID.
    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        availableInputDevices().first { $0.uid == uid }?.id
    }

    /// The device recording should use: the user's pick if it's connected,
    /// otherwise the built-in mic (so dictation never silently breaks).
    static func preferredInputDeviceID() -> AudioDeviceID? {
        let uid = SettingsManager.shared.selectedMicUID
        if !uid.isEmpty, let id = deviceID(forUID: uid) {
            return id
        }
        return builtInInputDeviceID()
    }

    static func deviceUID(_ device: AudioDeviceID) -> String? {
        cfStringProperty(device, kAudioDevicePropertyDeviceUID)
    }

    static func deviceName(_ device: AudioDeviceID) -> String? {
        cfStringProperty(device, kAudioObjectPropertyName)
    }

    private static func cfStringProperty(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString? = nil
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(device, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let str = value else { return nil }
        return str as String
    }

    /// Remove stale temp files from previous sessions
    static func cleanupStaleFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.lastPathComponent.hasPrefix("custom-wispr_") && file.pathExtension == "m4a" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    enum RecorderError: LocalizedError {
        case noMicrophone

        var errorDescription: String? {
            switch self {
            case .noMicrophone:
                return "No microphone available or sample rate is 0."
            }
        }
    }
}
