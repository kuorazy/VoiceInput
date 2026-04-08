import Cocoa
import Carbon

class TextInputInjector {
    private let pasteboard = NSPasteboard.general

    /// Supported CJK input source IDs (prefixes)
    private let cjkInputSourcePrefixes = [
        "com.apple.inputmethod.SCIM",       // Simplified Chinese
        "com.apple.inputmethod.TCIM",       // Traditional Chinese
        "com.apple.inputmethod.Japanese",   // Japanese
        "com.apple.inputmethod.Korean",     // Korean
        "com.apple.keylayout.Chinese",      // Chinese layout variants
        "com.apple.inputmethod",            // Generic input method (catch CJK IMEs)
    ]

    /// ASCII input sources to fall back to
    private let asciiInputSourceIDs = [
        "com.apple.keylayout.ABC",
        "com.apple.keylayout.US",
        "com.apple.keylayout.U.S.",
    ]

    func inject(_ text: String) {
        // Save current pasteboard
        let savedPasteboard = savePasteboard()

        // Set text to pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Check current input method and switch if needed
        let originalSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        let needsSwitch = isCJKInputSource(originalSource)

        if needsSwitch {
            _ = switchToASCIIInput()
        }

        // Small delay to let input source switch take effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Simulate Cmd+V
            self.simulatePaste()

            // Restore original input source
            if needsSwitch, let original = originalSource {
                self.restoreInputSource(original)
            }

            // Restore pasteboard after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.restorePasteboard(savedPasteboard)
            }
        }
    }

    // MARK: - Pasteboard

    private struct SavedPasteboard {
        var types: [NSPasteboard.PasteboardType]
        var data: [Data?]
    }

    private func savePasteboard() -> SavedPasteboard {
        let types = pasteboard.types ?? []
        var data: [Data?] = []
        for type in types {
            data.append(pasteboard.data(forType: type))
        }
        return SavedPasteboard(types: types, data: data)
    }

    private func restorePasteboard(_ saved: SavedPasteboard) {
        pasteboard.clearContents()
        for (i, type) in saved.types.enumerated() {
            if let d = saved.data[i] {
                pasteboard.setData(d, forType: type)
            }
        }
    }

    // MARK: - Input Source

    private func getInputSourceID(_ source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        let cfStr = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue()
        return cfStr as String
    }

    private func isCJKInputSource(_ source: TISInputSource?) -> Bool {
        guard let source = source, let id = getInputSourceID(source) else { return false }

        // Check if it's an ASCII source first
        for asciiID in asciiInputSourceIDs {
            if id == asciiID { return false }
        }

        // Check if it's a CJK input method
        for prefix in cjkInputSourcePrefixes {
            if id.hasPrefix(prefix) { return true }
        }

        return false
    }

    private func switchToASCIIInput() -> TISInputSource? {
        // Try each known ASCII source
        for id in asciiInputSourceIDs {
            if let source = findInputSource(id: id) {
                TISSelectInputSource(source)
                return source
            }
        }

        // Fallback: find any ASCII-capable source
        if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
            for source in sources {
                guard let category = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory),
                      Unmanaged<CFString>.fromOpaque(category).takeUnretainedValue() as String == kTISCategoryKeyboardInputSource as String else {
                    continue
                }
                if let id = getInputSourceID(source),
                   id.contains("ABC") || id.contains("US") || id.contains("U.S.") {
                    TISSelectInputSource(source)
                    return source
                }
            }
        }

        return nil
    }

    private func findInputSource(id: String) -> TISInputSource? {
        let dict = [kTISPropertyInputSourceID as String: id] as CFDictionary
        if let sources = TISCreateInputSourceList(dict, false)?.takeRetainedValue() as? [TISInputSource] {
            return sources.first
        }
        return nil
    }

    private func restoreInputSource(_ source: TISInputSource) {
        TISSelectInputSource(source)
    }

    // MARK: - Simulate Paste

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Cmd down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)

        // V down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)

        // V up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cghidEventTap)

        // Cmd up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
    }
}
