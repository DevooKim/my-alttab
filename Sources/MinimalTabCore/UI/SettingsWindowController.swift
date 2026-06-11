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
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    public func show() {
        // Rebuild the content on every open so the window always starts
        // fresh — on the "일반" tab, with no leftover recording state.
        window?.contentViewController = NSHostingController(rootView: SettingsView())
        window?.center()
        // An LSUIElement app must explicitly activate to bring its
        // settings window forward.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
