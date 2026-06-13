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
    @AppStorage(Preferences.Key.showMenuBarIcon) private var showMenuBarIcon = true

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarContent()
        } label: {
            // The label renders eagerly (the status item is visible at launch),
            // so the open observers hosted here are live immediately — unlike
            // the menu *content*, which mounts lazily on first open.
            Image(systemName: "rectangle.stack")
                .onReceive(NotificationCenter.default.publisher(for: OnboardingWindow.openNotification)) { _ in
                    openWindow(id: OnboardingWindow.id)
                }
                .modifier(OpenSettingsOnNotification())
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

/// Opens the Settings scene when `SettingsOpener` posts. Uses the macOS 14+
/// `openSettings` environment action (reliable, unlike the showSettingsWindow:
/// selector on macOS 26); falls back to the selector on macOS 13.
private struct OpenSettingsOnNotification: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14, *) {
            content.modifier(OpenSettingsModern())
        } else {
            content.onReceive(NotificationCenter.default.publisher(for: SettingsOpener.openNotification)) { _ in
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}

@available(macOS 14, *)
private struct OpenSettingsModern: ViewModifier {
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: SettingsOpener.openNotification)) { _ in
            openSettings()
        }
    }
}
