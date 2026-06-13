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
        window.title = L("window.settings.title")
        window.isReleasedWhenClosed = false
        // Modern translucent chrome: let the window's titlebar blend into the
        // content so the Liquid Glass / material backgrounds read as one
        // continuous surface (macOS 26 look; harmless on older systems).
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
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
