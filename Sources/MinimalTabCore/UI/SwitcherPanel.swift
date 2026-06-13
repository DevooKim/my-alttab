import AppKit
import SwiftUI

/// Borderless, non-activating floating panel. Non-activating is essential:
/// the user is holding a modifier over another app, and focus must not move
/// until they release it.
@MainActor
public final class SwitcherPanel: NSPanel {
    private let hostingView: NSHostingView<SwitcherView>
    /// Bumped on every show()/hide(). A hide animation's completion only
    /// orders the panel out if no show() happened while it was fading —
    /// otherwise a quick reopen (within the fade duration) would be
    /// hidden by the stale completion handler.
    private var generation = 0

    public init(model: SwitcherViewModel) {
        hostingView = NSHostingView(rootView: SwitcherView(model: model))
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .transient]
        hidesOnDeactivate = false
        contentView = hostingView
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    /// PRD 4.C: center on the screen containing the mouse cursor.
    /// PRD 2.A: fade-in with a light spring scale.
    public func show() {
        generation += 1
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        let screen = Self.screenUnderMouse()
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        setFrame(NSRect(origin: origin, size: size), display: true)

        alphaValue = 0
        contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.97, y: 0.97))
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            animator().alphaValue = 1
            contentView?.layer?.setAffineTransform(.identity)
        }
    }

    public func hide() {
        generation += 1
        let hideGeneration = generation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == hideGeneration else { return }
                self.orderOut(nil)
            }
        })
    }

    public static func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
