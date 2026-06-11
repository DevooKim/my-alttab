import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSWindowController {
    public convenience init() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "My AltTab 설정"
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    public func show() {
        window?.center()
        // An LSUIElement app must explicitly activate to bring its
        // settings window forward.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
