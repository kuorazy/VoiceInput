import Cocoa
import QuartzCore

class WaveformView: NSView {
    private let barWeights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let barCount = 5
    private let barWidth: CGFloat = 5
    private let barGap: CGFloat = 4
    private let maxBarHeight: CGFloat = 28
    private let minBarHeight: CGFloat = 4

    // Per-bar smoothing
    private var smoothedLevels: [CGFloat] = [0, 0, 0, 0, 0]
    private let attackCoeff: CGFloat = 0.4
    private let releaseCoeff: CGFloat = 0.15

    var isActive = false {
        didSet {
            if isActive {
                startDisplayLink()
            } else {
                stopDisplayLink()
                animateIdle()
            }
        }
    }

    private var currentRMS: CGFloat = 0
    private var displayLink: CVDisplayLink?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func updateRMS(_ rms: Float) {
        currentRMS = CGFloat(rms)
    }

    private func startDisplayLink() {
        stopDisplayLink()
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link = link else { return }
        self.displayLink = link

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, userInfo in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let view = Unmanaged<WaveformView>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async { view.tick() }
            return kCVReturnSuccess
        }, userInfo)

        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
    }

    private func tick() {
        guard isActive else { return }

        for i in 0..<barCount {
            let targetLevel = currentRMS * barWeights[i]

            // Add ±4% jitter for organic feel
            let jitter = CGFloat.random(in: -0.04...0.04)
            let jitteredTarget = targetLevel + jitter * targetLevel
            let clampedTarget = max(0, min(1, jitteredTarget))

            let coeff = clampedTarget > smoothedLevels[i] ? attackCoeff : releaseCoeff
            smoothedLevels[i] = smoothedLevels[i] + coeff * (clampedTarget - smoothedLevels[i])
        }

        needsDisplay = true
    }

    private func animateIdle() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        let step: CGFloat = 0.08
        var allDone = true
        for i in 0..<barCount {
            if smoothedLevels[i] > 0.02 {
                smoothedLevels[i] = max(0, smoothedLevels[i] - step)
                allDone = false
            } else {
                smoothedLevels[i] = 0
            }
        }
        needsDisplay = true
        if !allDone {
            perform(#selector(idleStep), with: nil, afterDelay: 0.016)
        }
    }

    @objc private func idleStep() {
        animateIdle()
    }

    override func draw(_ dirtyRect: NSRect) {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barGap
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2

        for i in 0..<barCount {
            let level = smoothedLevels[i]
            let barHeight = minBarHeight + (maxBarHeight - minBarHeight) * level
            let x = startX + CGFloat(i) * (barWidth + barGap)
            let y = centerY - barHeight / 2

            let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)

            let alpha: CGFloat = 0.6 + 0.4 * level
            NSColor.white.withAlphaComponent(alpha).setFill()
            path.fill()
        }
    }

    deinit {
        stopDisplayLink()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
}
