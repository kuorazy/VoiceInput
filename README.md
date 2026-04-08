# VoiceInput

A macOS menu bar app that turns your voice into text input. Hold the **Fn key** to speak, release to type — works in any app.

## Features

- **Fn key trigger** — Hold Fn to record, release to transcribe and input
- **Real-time feedback** — Floating overlay with waveform animation and live transcript
- **Multi-language** — Simplified Chinese, Traditional Chinese, English, Japanese, Korean
- **Auto punctuation** — Automatic comma and period insertion
- **CJK input method handling** — Automatically switches to ASCII input for paste, then restores
- **Optional LLM refinement** — Post-process transcription to fix homophone errors (e.g. "配森" → "Python")
- **Lightweight** — Uses Apple Speech framework, no heavy ML models required

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (M1/M2/M3/M4)
- Xcode (for building)

## Build & Run

```bash
git clone https://github.com/kuorazy/VoiceInput.git
cd VoiceInput
make run
```

## Permissions

On first launch, grant the following permissions:

1. **Microphone** — System Settings → Privacy & Security → Microphone
2. **Speech Recognition** — System Settings → Privacy & Security → Speech Recognition
3. **Accessibility** — System Settings → Privacy & Security → Accessibility

> After each rebuild, you may need to toggle the Accessibility permission off and on again for VoiceInput.

## Usage

1. The app appears as a microphone icon in the menu bar
2. **Hold Fn** — Start speaking, the floating overlay shows waveform and live transcript
3. **Release Fn** — Text is automatically typed into the active input field
4. Click the menu bar icon to change language or configure LLM

## LLM Refinement (Optional)

Enable LLM post-processing to fix common speech recognition errors like misrecognized technical terms. Supports any OpenAI-compatible API.

1. Click menu bar icon → **LLM Refinement → Enabled**
2. Click **Settings…** and configure:
   - **API Base URL** — e.g. `https://api.openai.com/v1`
   - **API Key**
   - **Model** — default: `gpt-4o-mini`

## Other Commands

```bash
make build    # Build only
make install  # Build and install to /Applications
make clean    # Remove build artifacts
```

## License

MIT
