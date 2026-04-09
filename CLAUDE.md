# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
make build    # Compile to .build/VoiceInput.app
make run      # Build and launch
make install  # Build and install to /Applications/VoiceInput.app
make clean    # Remove .build directory
```

The Makefile uses direct `swiftc` compilation (not Swift Package Manager). Target: `arm64-apple-macosx14.0`. There is no test suite.

## Architecture

macOS menu bar app (LSUIElement=true, no dock icon) that converts voice to text via Fn key trigger. AppDelegate is the central coordinator using callback-based communication.

**Data flow:** FnKeyMonitor (event tap) → AudioRecorder + SpeechRecognizer → [optional LLMRefiner] → TextInputInjector (paste via Cmd+V) → active app

**Key components** (`Sources/VoiceInput/`):
- **FnKeyMonitor** — CGEvent tap for Fn key, suppresses emoji picker
- **AudioRecorder** — AudioQueue at 16kHz, provides RMS for waveform
- **SpeechRecognizer** — Apple SFSpeechRecognizer, multi-language (zh-CN/zh-TW/en-US/ja-JP/ko-KR)
- **FloatingOverlay** / **WaveformView** — Floating panel with 5-bar waveform (CVDisplayLink), live transcript, LLM spinner
- **TextInputInjector** — Pastes text via Cmd+V; detects CJK input methods, temporarily switches to ASCII for paste, restores original IME; preserves pasteboard state
- **LLMRefiner** — OpenAI-compatible API call to fix homophone/tech term errors
- **SettingsWindowController** — Settings UI with custom PasteableTextField subclasses (needed because menu bar apps lack Edit menu for Cmd+C/V)

**Configuration** via UserDefaults: `RecognitionLanguage`, `LLMEnabled`, `LLMApiBaseURL`, `LLMApiKey`, `LLMModel`

**Required permissions:** Accessibility (Fn key tap), Microphone, Speech Recognition

**Entitlements:** No sandbox; Apple Events automation and microphone audio input enabled.

## Important Details

- Text injection uses Carbon TIS API for IME switching — CJK users need ASCII mode for Cmd+V to work correctly
- No external dependencies — all native Apple frameworks (Cocoa, Speech, AVFoundation, AudioToolbox, Carbon, CoreVideo)
- Settings text fields use `PasteableTextField`/`PasteableSecureTextField` subclasses that override `performKeyEquivalent` to handle Cmd+V/C/X/A, since menu bar apps have no main menu bar for responder chain dispatch
