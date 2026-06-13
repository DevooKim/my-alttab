import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSWindowController {
    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("window.settings.title")
        window.isReleasedWhenClosed = false
        // Start compact; let the user drag to grow. Content scrolls when it
        // exceeds the window height.
        window.minSize = NSSize(width: 460, height: 320)
        window.setContentSize(NSSize(width: 460, height: 420))
        self.init(window: window)
    }

    public func show() {
        // Rebuild the content on every open so the window always starts
        // fresh — on the "일반" tab, with no leftover recording state.
        let host = NSHostingController(rootView: SettingsView())
        // Don't let SwiftUI force the window to the content's intrinsic size —
        // we want a fixed default the user can resize, with content scrolling.
        host.sizingOptions = []
        window?.contentViewController = host
        window?.setContentSize(NSSize(width: 460, height: 420))
        window?.center()
        // An LSUIElement app must explicitly activate to bring its
        // settings window forward.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
