import Cocoa

// NSTextField subclass that handles Cmd+C/V/X/A key equivalents
// Needed because this menu bar app has no main menu bar, so standard
// Edit menu commands are not available through the responder chain.
class PasteableTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers {
            if let editor = currentEditor() {
                switch chars {
                case "c": editor.copy(self); return true
                case "v": editor.paste(self); return true
                case "x": editor.cut(self); return true
                case "a": editor.selectAll(self); return true
                default: break
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

class PasteableSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers {
            if let editor = currentEditor() {
                switch chars {
                case "v": editor.paste(self); return true
                case "a": editor.selectAll(self); return true
                default: break
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LLM Settings"
        window.isReleasedWhenClosed = false
        window.level = .floating

        let viewController = SettingsViewController()
        window.contentViewController = viewController

        self.init(window: window)
    }
}

class SettingsViewController: NSViewController {
    private var baseURLField: PasteableTextField!
    private var apiKeyField: PasteableSecureTextField!
    private var modelField: PasteableTextField!
    private var testButton: NSButton!
    private var saveButton: NSButton!
    private var statusLabel: NSTextField!

    override func loadView() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))

        let defaults = UserDefaults.standard

        // API Base URL
        let baseURLLabel = makeLabel("API Base URL:")
        baseURLLabel.frame = NSRect(x: 20, y: 220, width: 120, height: 24)
        contentView.addSubview(baseURLLabel)

        baseURLField = PasteableTextField(frame: NSRect(x: 150, y: 220, width: 310, height: 24))
        baseURLField.placeholderString = "https://api.openai.com/v1"
        baseURLField.stringValue = defaults.string(forKey: "LLMApiBaseURL") ?? ""
        contentView.addSubview(baseURLField)

        // API Key
        let apiKeyLabel = makeLabel("API Key:")
        apiKeyLabel.frame = NSRect(x: 20, y: 180, width: 120, height: 24)
        contentView.addSubview(apiKeyLabel)

        apiKeyField = PasteableSecureTextField(frame: NSRect(x: 150, y: 180, width: 310, height: 24))
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.stringValue = defaults.string(forKey: "LLMApiKey") ?? ""
        contentView.addSubview(apiKeyField)

        // Model
        let modelLabel = makeLabel("Model:")
        modelLabel.frame = NSRect(x: 20, y: 140, width: 120, height: 24)
        contentView.addSubview(modelLabel)

        modelField = PasteableTextField(frame: NSRect(x: 150, y: 140, width: 310, height: 24))
        modelField.placeholderString = "gpt-4o-mini"
        modelField.stringValue = defaults.string(forKey: "LLMModel") ?? ""
        contentView.addSubview(modelField)

        // Buttons
        testButton = NSButton(frame: NSRect(x: 150, y: 90, width: 80, height: 32))
        testButton.title = "Test"
        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(testClicked)
        contentView.addSubview(testButton)

        saveButton = NSButton(frame: NSRect(x: 240, y: 90, width: 80, height: 32))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        contentView.addSubview(saveButton)

        // Status label
        statusLabel = NSTextField(frame: NSRect(x: 150, y: 60, width: 310, height: 20))
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.drawsBackground = false
        statusLabel.isBezeled = false
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = ""
        contentView.addSubview(statusLabel)

        self.view = contentView
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13)
        label.alignment = .right
        return label
    }

    @objc private func testClicked() {
        statusLabel.stringValue = "Testing…"
        statusLabel.textColor = .secondaryLabelColor
        testButton.isEnabled = false

        // Temporarily save for test
        let refiner = LLMRefiner()
        let savedBase = UserDefaults.standard.string(forKey: "LLMApiBaseURL")
        let savedKey = UserDefaults.standard.string(forKey: "LLMApiKey")
        let savedModel = UserDefaults.standard.string(forKey: "LLMModel")

        // Temporarily set current field values
        UserDefaults.standard.set(baseURLField.stringValue, forKey: "LLMApiBaseURL")
        UserDefaults.standard.set(apiKeyField.stringValue, forKey: "LLMApiKey")
        UserDefaults.standard.set(modelField.stringValue.isEmpty ? "gpt-4o-mini" : modelField.stringValue, forKey: "LLMModel")

        refiner.testConnection { [weak self] result in
            DispatchQueue.main.async {
                self?.testButton.isEnabled = true
                switch result {
                case .success(let text):
                    self?.statusLabel.stringValue = "OK: \(text.prefix(50))"
                    self?.statusLabel.textColor = .systemGreen
                case .failure(let error):
                    self?.statusLabel.stringValue = "Failed: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                }
                // Restore saved values if they were different
                UserDefaults.standard.set(savedBase, forKey: "LLMApiBaseURL")
                UserDefaults.standard.set(savedKey, forKey: "LLMApiKey")
                UserDefaults.standard.set(savedModel, forKey: "LLMModel")
            }
        }
    }

    @objc private func saveClicked() {
        let defaults = UserDefaults.standard
        defaults.set(baseURLField.stringValue, forKey: "LLMApiBaseURL")
        defaults.set(apiKeyField.stringValue, forKey: "LLMApiKey")
        defaults.set(modelField.stringValue.isEmpty ? "gpt-4o-mini" : modelField.stringValue, forKey: "LLMModel")

        statusLabel.stringValue = "Saved"
        statusLabel.textColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.statusLabel.stringValue = ""
        }
    }
}
