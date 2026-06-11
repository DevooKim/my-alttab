import AppKit
import CoreGraphics

public enum SwitcherMode {
    case global
    case sameApp
}

/// Set while the settings window is recording a new shortcut. The global
/// event tap must pass events through untouched during recording —
/// otherwise pressing the current shortcut (e.g. Option+Tab) triggers the
/// switcher and swallows the event before the recorder can capture it.
public enum ShortcutCapture {
    public static var isRecording = false
}

/// Global event tap. Requires Accessibility permission (already mandatory
/// for window enumeration). All callbacks fire on the main thread.
public final class HotKeyMonitor {
    /// Fired on every matching trigger press (first press opens the
    /// switcher; repeats advance the selection).
    public var onTrigger: ((SwitcherMode) -> Void)?
    /// Raw flags on flagsChanged during an active session; the controller
    /// checks `modifiersStillHeld` against the shortcut that opened the
    /// session and commits when the modifiers are released.
    public var onFlagsChanged: ((CGEventFlags) -> Void)?
    /// Fired when Escape is pressed during an active session.
    public var onCancel: (() -> Void)?
    /// Queried to decide whether flagsChanged/Escape events matter and
    /// whether trigger keyDowns should be swallowed.
    public var isSessionActive: () -> Bool = { false }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let preferences: Preferences

    public init(preferences: Preferences = .shared) {
        self.preferences = preferences
    }

    public func start() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("MinimalTab: failed to create event tap (accessibility permission missing?)")
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("MinimalTab: event tap started")
    }

    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disables slow taps; re-enable and pass the event on.
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            if ShortcutCapture.isRecording {
                return Unmanaged.passUnretained(event)
            }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            if preferences.globalShortcut.matches(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async { self.onTrigger?(.global) }
                return nil // swallow: the focused app must not receive it
            }
            if preferences.sameAppShortcut.matches(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async { self.onTrigger?(.sameApp) }
                return nil
            }
            if isSessionActive() && keyCode == 53 { // Escape
                DispatchQueue.main.async { self.onCancel?() }
                return nil
            }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            guard isSessionActive() else { return Unmanaged.passUnretained(event) }
            let flags = event.flags
            DispatchQueue.main.async { self.onFlagsChanged?(flags) }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
