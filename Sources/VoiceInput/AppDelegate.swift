import Cocoa
import Speech

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var fnMonitor: FnKeyMonitor!
    var audioRecorder: AudioRecorder!
    var speechRecognizer: SpeechRecognizer!
    var floatingOverlay: FloatingOverlay!
    var textInjector: TextInputInjector!
    var llmRefiner: LLMRefiner!
    var settingsWindowController: SettingsWindowController?

    let languageMenu: NSMenu = {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let langs: [(String, String)] = [
            ("简体中文", "zh-CN"),
            ("繁體中文", "zh-TW"),
            ("English", "en-US"),
            ("日本語", "ja-JP"),
            ("한국어", "ko-KR"),
        ]
        for (title, code) in langs {
            let item = menu.addItem(withTitle: title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.representedObject = code
            item.target = nil
        }
        return menu
    }()

    var llmEnabledMenuItem: NSMenuItem!
    var llmSettingsMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestPermissions()

        textInjector = TextInputInjector()
        audioRecorder = AudioRecorder()
        speechRecognizer = SpeechRecognizer()
        floatingOverlay = FloatingOverlay()
        llmRefiner = LLMRefiner()

        fnMonitor = FnKeyMonitor()
        fnMonitor.onKeyDown = { [weak self] in self?.startRecording() }
        fnMonitor.onKeyUp = { [weak self] in self?.stopRecording() }

        setupMenuBar()

        speechRecognizer.onPartialResult = { [weak self] text in
            DispatchQueue.main.async { self?.floatingOverlay.updateTranscript(text) }
        }
        speechRecognizer.onFinalResult = { [weak self] text in
            DispatchQueue.main.async { self?.handleFinalResult(text) }
        }
        speechRecognizer.onError = { [weak self] error in
            DispatchQueue.main.async { self?.handleError(error) }
        }

        audioRecorder.onRMSUpdate = { [weak self] rms in
            DispatchQueue.main.async { self?.floatingOverlay.updateWaveform(rms) }
        }

        fnMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        fnMonitor.stop()
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition authorization: \(status.rawValue)")
            }
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice Input")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()

        let langItem = menu.addItem(withTitle: "Language", action: nil, keyEquivalent: "")
        langItem.submenu = languageMenu
        updateLanguageCheckmark()

        menu.addItem(NSMenuItem.separator())

        let llmItem = menu.addItem(withTitle: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmSubMenu = NSMenu()
        llmEnabledMenuItem = llmSubMenu.addItem(withTitle: "Enabled", action: #selector(toggleLLM(_:)), keyEquivalent: "")
        llmEnabledMenuItem.target = self
        llmEnabledMenuItem.state = UserDefaults.standard.bool(forKey: "LLMEnabled") ? .on : .off
        llmSettingsMenuItem = llmSubMenu.addItem(withTitle: "Settings…", action: #selector(showLLMSettings(_:)), keyEquivalent: "")
        llmSettingsMenuItem.target = self
        llmItem.submenu = llmSubMenu

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit VoiceInput", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
    }

    private func updateLanguageCheckmark() {
        let current = UserDefaults.standard.string(forKey: "RecognitionLanguage") ?? "zh-CN"
        for item in languageMenu.items {
            let code = item.representedObject as? String ?? ""
            item.state = (code == current) ? .on : .off
            item.target = self
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        UserDefaults.standard.set(code, forKey: "RecognitionLanguage")
        updateLanguageCheckmark()
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        let newValue = !UserDefaults.standard.bool(forKey: "LLMEnabled")
        UserDefaults.standard.set(newValue, forKey: "LLMEnabled")
        sender.state = newValue ? .on : .off
    }

    @objc private func showLLMSettings(_ sender: NSMenuItem) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Recording

    private func startRecording() {
        let lang = UserDefaults.standard.string(forKey: "RecognitionLanguage") ?? "zh-CN"
        speechRecognizer.startRecognition(language: lang)
        audioRecorder.start()
        floatingOverlay.show()
    }

    private func stopRecording() {
        audioRecorder.stop()
        speechRecognizer.stopRecognition()
    }

    private func handleFinalResult(_ text: String) {
        guard !text.isEmpty else {
            floatingOverlay.dismiss()
            return
        }

        let llmEnabled = UserDefaults.standard.bool(forKey: "LLMEnabled")
        let hasApiKey = !(UserDefaults.standard.string(forKey: "LLMApiKey") ?? "").isEmpty

        if llmEnabled && hasApiKey {
            floatingOverlay.showRefining()
            llmRefiner.refine(text) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let refined):
                        self?.injectAndDismiss(refined)
                    case .failure:
                        self?.injectAndDismiss(text)
                    }
                }
            }
        } else {
            injectAndDismiss(text)
        }
    }

    private func injectAndDismiss(_ text: String) {
        floatingOverlay.dismiss {
            self.textInjector.inject(text)
        }
    }

    private func handleError(_ error: Error) {
        print("Speech recognition error: \(error.localizedDescription)")
        floatingOverlay.dismiss()
    }
}
