import SwiftUI
import MinimalTabCore

/// SwiftUI App/Scene entry point. The CGEventTap, hotkey wiring, and switcher
/// orchestration still live in `AppDelegate`, retained here via
/// `NSApplicationDelegateAdaptor` — the tap is a C callback on the main run
/// loop and genuinely needs a classic app delegate.
@main
struct MinimalTabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            // The label renders eagerly (the status item is visible at launch),
            // so the onboarding-open observer hosted here is live immediately —
            // unlike the menu *content*, which mounts lazily on first open.
            Image(systemName: "rectangle.stack")
                .onReceive(NotificationCenter.default.publisher(for: OnboardingWindow.openNotification)) { _ in
                    openWindow(id: OnboardingWindow.id)
                }
        }

        Settings {
            SettingsView()
        }

        Window(L("window.onboarding.title"), id: OnboardingWindow.id) {
            OnboardingView(onFinish: { OnboardingWindow.finish() })
                .fixedSize()
        }
        .windowResizability(.contentSize)
    }
}
