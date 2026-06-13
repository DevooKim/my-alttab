import AppKit
import SwiftUI

@MainActor
public final class OnboardingWindowController: NSWindowController {
    private var onFinish: (() -> Void)?

    public convenience init(onFinish: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "My AltTab 시작하기"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        self.onFinish = onFinish
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(onFinish: { [weak self] in self?.finish() })
        )
    }

    public func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        onFinish?()
        window?.close()
    }
}
