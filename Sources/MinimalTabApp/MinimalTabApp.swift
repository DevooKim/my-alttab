import SwiftUI
import MinimalTabCore

/// SwiftUI App/Scene entry point. The CGEventTap, hotkey wiring, status bar,
/// onboarding, and switcher orchestration still live in `AppDelegate`, retained
/// here via `NSApplicationDelegateAdaptor` — the tap is a C callback on the main
/// run loop and genuinely needs a classic app delegate.
@main
struct MinimalTabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Placeholder scene. A SwiftUI `App` requires at least one Scene;
        // status bar / settings / onboarding are still delegate-driven in this
        // phase and become real Scenes (MenuBarExtra / Settings / Window) in
        // later phases.
        Settings { EmptyView() }
    }
}
