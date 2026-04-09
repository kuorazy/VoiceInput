import Cocoa

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class FloatingOverlay {
    private var panel: FloatingPanel!
    private var waveformView: WaveformView!
    private var transcriptLabel: NSTextField!
    private var refiningSpinner: NSProgressIndicator!
    private var refiningLabel: NSTextField!
    private var containerView: NSVisualEffectView!
    private var wrapperView: NSView!

    private var isShowing = false

    init() {
        setupPanel()
    }

    private func setupPanel() {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 56),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // Transparent wrapper as contentView to prevent white background
        wrapperView = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 56))
        wrapperView.wantsLayer = true
        wrapperView.layer?.backgroundColor = NSColor.clear.cgColor

        // Capsule visual effect view inside wrapper
        containerView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 280, height: 56))
        containerView.autoresizingMask = [.width, .height]
        containerView.material = .hudWindow
        containerView.blendingMode = .behindWindow
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 28
        containerView.layer?.masksToBounds = true
        wrapperView.addSubview(containerView)

        // Waveform view
        waveformView = WaveformView(frame: NSRect(x: 12, y: 12, width: 44, height: 32))
        containerView.addSubview(waveformView)

        // Transcript label
        transcriptLabel = NSTextField(frame: NSRect(x: 64, y: 0, width: 200, height: 56))
        transcriptLabel.isEditable = false
        transcriptLabel.isSelectable = false
        transcriptLabel.drawsBackground = false
        transcriptLabel.isBezeled = false
        transcriptLabel.textColor = .white
        transcriptLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        transcriptLabel.alignment = .left
        transcriptLabel.lineBreakMode = .byTruncatingTail
        transcriptLabel.cell?.truncatesLastVisibleLine = true
        transcriptLabel.stringValue = ""
        containerView.addSubview(transcriptLabel)

        // Refining indicator (spinner + label)
        refiningSpinner = NSProgressIndicator(frame: NSRect(x: 64, y: 18, width: 20, height: 20))
        refiningSpinner.style = .spinning
        refiningSpinner.controlSize = .small
        refiningSpinner.isHidden = true
        containerView.addSubview(refiningSpinner)

        refiningLabel = NSTextField(frame: NSRect(x: 88, y: 0, width: 160, height: 56))
        refiningLabel.isEditable = false
        refiningLabel.isSelectable = false
        refiningLabel.drawsBackground = false
        refiningLabel.isBezeled = false
        refiningLabel.textColor = NSColor.white.withAlphaComponent(0.8)
        refiningLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        refiningLabel.alignment = .left
        refiningLabel.stringValue = ""
        refiningLabel.isHidden = true
        containerView.addSubview(refiningLabel)

        panel.contentView = wrapperView
    }

    private func reposition(width: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelWidth = max(200, min(600, width))
        let panelHeight: CGFloat = 56
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.minY + 40
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }

    func show() {
        guard !isShowing else { return }
        isShowing = true
        waveformView.isActive = true
        transcriptLabel.stringValue = "正在聆听…"
        transcriptLabel.isHidden = false
        refiningSpinner.isHidden = true
        refiningSpinner.stopAnimation(nil)
        refiningLabel.isHidden = true

        let estimatedWidth: CGFloat = 220
        reposition(width: estimatedWidth)

        // Entrance spring animation
        wrapperView.wantsLayer = true
        wrapperView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        wrapperView.layer?.position = CGPoint(x: panel.frame.width / 2, y: panel.frame.height / 2)

        panel.alphaValue = 0
        wrapperView.layer?.setValue(0.3, forKeyPath: "transform.scale")
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            self.panel.alphaValue = 1
            self.wrapperView.layer?.setValue(1.0, forKeyPath: "transform.scale")
        }
    }

    func updateTranscript(_ text: String) {
        guard isShowing else { return }
        transcriptLabel.stringValue = text.isEmpty ? "正在聆听…" : text
        resizeForText()
    }

    func updateWaveform(_ rms: Float) {
        waveformView.updateRMS(rms)
    }

    func showRefining() {
        transcriptLabel.isHidden = true
        refiningSpinner.isHidden = false
        refiningSpinner.startAnimation(nil)
        refiningLabel.isHidden = false
        refiningLabel.stringValue = "Refining…"
        waveformView.isActive = false

        // Resize for refining state
        let totalWidth: CGFloat = 12 + 44 + 8 + 20 + 4 + 100 + 20
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            self.reposition(width: totalWidth)
        })
    }

    func dismiss(completion: (() -> Void)? = nil) {
        guard isShowing else {
            completion?()
            return
        }
        isShowing = false
        waveformView.isActive = false
        refiningSpinner.stopAnimation(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            self.panel.alphaValue = 0
            self.wrapperView.layer?.setValue(0.5, forKeyPath: "transform.scale")
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            self.wrapperView.layer?.setValue(1.0, forKeyPath: "transform.scale")
            self.transcriptLabel.stringValue = ""
            completion?()
        })
    }

    private func resizeForText() {
        let text = transcriptLabel.stringValue
        let font = transcriptLabel.font ?? NSFont.systemFont(ofSize: 14)
        let textWidth = (text as NSString).boundingRect(
            with: NSSize(width: CGFloat.greatestFiniteMagnitude, height: 56),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font]
        ).width

        let labelWidth = max(160, min(560, textWidth + 20))
        let totalWidth = 12 + 44 + 8 + labelWidth + 20

        transcriptLabel.frame = NSRect(x: 64, y: 0, width: labelWidth, height: 56)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            self.reposition(width: totalWidth)
        })
    }
}
