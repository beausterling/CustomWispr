#!/usr/bin/env swift
//
// verify-mic-capture.swift — regression guard for the "0 frames captured" bug.
//
// Background: v1.5 tried to force dictation onto a specific input device by
// calling AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice) on
// AVAudioEngine's input node. On real hardware that call returns noErr and
// reports a valid format, but the engine then captures ZERO audio frames —
// every recording uploaded an empty file and OpenAI returned
// "audio_too_short". The working approach is to switch the *system default
// input device* (which AVAudioEngine reliably follows) and restore it after.
//
// This script proves the failure mode and the fix so nobody silently
// reintroduces the broken pin. Run it after touching AudioRecorder.swift:
//
//     swift scripts/verify-mic-capture.swift
//
// It exits non-zero if the "follow default device" path fails to capture
// audio (which is what dictation depends on). Requires mic permission for the
// terminal running it.

import AVFoundation
import CoreAudio
import Foundation

func builtInInputID() -> AudioDeviceID? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
    let n = Int(size) / MemoryLayout<AudioDeviceID>.size
    var devs = [AudioDeviceID](repeating: 0, count: n)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devs)
    for d in devs {
        var t: UInt32 = 0
        var ts = UInt32(MemoryLayout<UInt32>.size)
        var ta = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        if AudioObjectGetPropertyData(d, &ta, 0, nil, &ts, &t) == noErr,
           t == kAudioDeviceTransportTypeBuiltIn {
            return d
        }
    }
    return nil
}

/// Capture ~1.5s from AVAudioEngine and return the frame count.
/// `pin == true` reproduces the BROKEN v1.5 approach (expected: 0 frames).
func captureFrames(pinDeviceID: AudioDeviceID?) -> Int64 {
    let engine = AVAudioEngine()
    let input = engine.inputNode
    if let id = pinDeviceID, let au = input.audioUnit {
        var dev = id
        _ = AudioUnitSetProperty(au, kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0, &dev, UInt32(MemoryLayout<AudioDeviceID>.size))
    }
    let fmt = input.outputFormat(forBus: 0)
    var frames: Int64 = 0
    input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { buf, _ in
        frames += Int64(buf.frameLength)
    }
    engine.prepare()
    do { try engine.start() } catch { return -1 }
    Thread.sleep(forTimeInterval: 1.5)
    input.removeTap(onBus: 0)
    engine.stop()
    return frames
}

func currentDefaultInput() -> AudioDeviceID? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var dev: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr,
          dev != 0 else { return nil }
    return dev
}

@discardableResult
func setDefaultInput(_ device: AudioDeviceID) -> Bool {
    var dev = device
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
        UInt32(MemoryLayout<AudioDeviceID>.size), &dev) == noErr
}

guard let builtIn = builtInInputID() else {
    FileHandle.standardError.write("SKIP: no built-in microphone found.\n".data(using: .utf8)!)
    exit(0)
}

// Mirror the app exactly: temporarily switch the system default input to the
// chosen device (here, built-in), capture, then restore the previous default.
let previousDefault = currentDefaultInput()
setDefaultInput(builtIn)
let okFrames = captureFrames(pinDeviceID: nil)
if let prev = previousDefault { setDefaultInput(prev) }
print("switch-default-then-follow capture (the app's approach): \(okFrames) frames")

// Document the banned path: manual AudioUnit device pin. On this machine it may
// or may not capture, but it returns 0 frames on real hardware in the field —
// that is the exact bug this script exists to prevent reintroducing.
let pinFrames = captureFrames(pinDeviceID: builtIn)
print("audio-unit-pin capture: \(pinFrames) frames (BANNED approach — see AudioRecorder.swift)")

guard okFrames > 0 else {
    FileHandle.standardError.write(
        "FAIL: AVAudioEngine captured 0 frames from the chosen device — dictation is broken.\n"
            .data(using: .utf8)!)
    exit(1)
}
print("PASS: microphone capture works (\(okFrames) frames).")
