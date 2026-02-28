import AVFoundation
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?

    func startRecording() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("wisprflow_\(UUID().uuidString).m4a")
        self.tempFileURL = fileURL

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Use outputFormat (not inputFormat) to avoid crashes on some hardware
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            throw RecorderError.noMicrophone
        }

        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: recordingFormat.sampleRate,
                AVNumberOfChannelsKey: recordingFormat.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        )

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            try? audioFile.write(from: buffer)
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
        audioFile = nil
        return tempFileURL
    }

    func cleanup() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
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
