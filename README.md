# CustomWispr

A customizable, open-source speech-to-text app for macOS.

Hold the **fn** key to record your speech, release to transcribe it with OpenAI's Whisper API, clean it up with GPT, and paste the result directly into any active text field.

## Features

- **Global fn key trigger** — works in any app, no menubar interaction needed
- **Floating overlay UI** — shows recording/processing status as a compact overlay
- **AI-powered cleanup** — removes filler words (uh, um) and fixes grammar while preserving your natural voice
- **Clipboard-safe paste** — saves and restores your clipboard contents after injecting text
- **Menu bar controls** — quit from the menu bar icon
- **Lightweight** — pure Swift, no Electron, no dependencies beyond macOS system frameworks

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)
- OpenAI API key
- Microphone permission
- Accessibility permission (for simulating Cmd+V paste)

## Installation

### Intel Mac

```bash
chmod +x build.sh
./build.sh
```

### Apple Silicon Mac (M1/M2/M3/M4)

```bash
chmod +x build-arm64.sh
./build-arm64.sh
```

Then move the app to your Applications folder:

```bash
cp -r CustomWispr.app /Applications/
```

## Setup

### 1. Add your OpenAI API key

Create the config file:

```bash
echo "OPENAI_API_KEY=your-key-here" > ~/.custom-wispr.env
chmod 600 ~/.custom-wispr.env
```

### 2. Configure the fn key

Go to **System Settings > Keyboard** and set **"Press fn key to"** to **"Do Nothing"**. This allows CustomWispr to capture the fn key as a trigger.

### 3. Grant permissions

On first launch, macOS will prompt you to grant:

- **Accessibility** — needed to simulate Cmd+V for pasting transcribed text
- **Microphone** — needed to record your speech

If you miss the prompts, go to **System Settings > Privacy & Security** and enable CustomWispr under Accessibility and Microphone.

## Usage

1. Launch `CustomWispr.app`
2. **Hold fn** — a floating overlay appears and recording begins
3. **Release fn** — recording stops, audio is sent to Whisper for transcription, then cleaned up by GPT
4. The cleaned text is pasted into whatever text field is currently focused

## Architecture

| File | Purpose |
|---|---|
| `main.swift` | App entry point |
| `AppDelegate.swift` | Orchestrates the full pipeline: key events, recording, transcription, cleanup, and injection |
| `Config.swift` | Loads OpenAI API key from `~/.custom-wispr.env` or environment variables |
| `KeyMonitor.swift` | Global fn key listener using a CGEvent tap |
| `AudioRecorder.swift` | Records microphone input to a temporary audio file using AVAudioEngine |
| `WhisperService.swift` | Sends audio to the OpenAI Whisper API for transcription |
| `AICleanupService.swift` | Sends raw transcription to GPT for light cleanup (filler removal, grammar fixes) |
| `TextInjector.swift` | Pastes text into the active field via clipboard + Cmd+V, then restores the original clipboard |
| `OverlayWindow.swift` | Floating status overlay that shows recording/processing state |

## Troubleshooting

**fn key doesn't trigger recording**
- Make sure **System Settings > Keyboard > "Press fn key to"** is set to **"Do Nothing"**
- Make sure Accessibility permission is granted for CustomWispr

**No transcription / empty result**
- Check that your API key is valid in `~/.custom-wispr.env`
- Check the console output: run the app from Terminal with `./CustomWispr.app/Contents/MacOS/CustomWispr` to see logs

**Text doesn't paste**
- Ensure Accessibility permission is granted — the app needs it to simulate Cmd+V
- Make sure a text field is focused when you release the fn key

**"Microphone access denied" error**
- Go to **System Settings > Privacy & Security > Microphone** and enable CustomWispr

**Build fails**
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Make sure you're using the correct build script for your Mac architecture

## License

MIT
