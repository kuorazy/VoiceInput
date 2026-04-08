import Cocoa
import Carbon

class FnKeyMonitor {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var isKeyDown = false

    func start() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: fnKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("[VoiceInput] Failed to create event tap. Check Accessibility permissions.")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}

private func fnKeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
    let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()

    // Handle tap disabled by system
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = monitor.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let fnKeycode: Int64 = 63 // Fn key keycode

    guard keycode == fnKeycode else {
        return Unmanaged.passRetained(event)
    }

    // Determine key state
    let isKeyDown: Bool
    if type == .keyDown {
        isKeyDown = true
    } else if type == .keyUp {
        isKeyDown = false
    } else if type == .flagsChanged {
        let flags = event.flags
        let fnFlag: CGEventFlags = .maskSecondaryFn
        isKeyDown = flags.contains(fnFlag)
    } else {
        return Unmanaged.passRetained(event)
    }

    if isKeyDown && !monitor.isKeyDown {
        monitor.isKeyDown = true
        monitor.onKeyDown?()
    } else if !isKeyDown && monitor.isKeyDown {
        monitor.isKeyDown = false
        monitor.onKeyUp?()
    }

    // Suppress Fn event to prevent emoji picker
    return nil
}
