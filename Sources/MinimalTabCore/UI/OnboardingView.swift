import SwiftUI
import AppKit

/// First-run welcome: app intro, key shortcuts, and an inline Accessibility
/// permission prompt with live status. Shown once (see
/// Preferences.hasCompletedOnboarding).
public struct OnboardingView: View {
    /// Called when the user clicks "시작하기".
    var onFinish: () -> Void

    @State private var accessibilityGranted = AccessibilityPermission.isGranted
    @State private var pollTimer: Timer?

    public init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    private var shortcuts: [(keys: String, label: String)] {
        [
            ("⌥⇥", L("onboarding.shortcut.global")),
            ("⌥`", L("onboarding.shortcut.sameApp")),
            ("⇧", L("onboarding.shortcut.reverse")),
            ("W / Q", L("onboarding.shortcut.quick")),
        ]
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("My AltTab")
                .font(.title.bold())
            Text(L("onboarding.subtitle"))
                .foregroundColor(.secondary)

            Divider()

            shortcutList
                .padding(.horizontal, 8)

            Divider()

            permissionRow

            startButton
        }
        .padding(28)
        .frame(width: 420)
        .onAppear(perform: startPolling)
        .onDisappear(perform: stopPolling)
    }

    /// Shortcut key chips. Glass capsules grouped in a `GlassEffectContainer`
    /// on macOS 26 (shared sampling region); plain rounded fills on macOS 13–15.
    @ViewBuilder
    private var shortcutList: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                shortcutRows
            }
        } else {
            shortcutRows
        }
    }

    private var shortcutRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(shortcuts, id: \.keys) { item in
                HStack(spacing: 12) {
                    chipLabel(item.keys)
                    Text(item.label)
                    Spacer()
                }
            }
        }
    }

    /// A single key chip: glass capsule on macOS 26, the original tinted
    /// rounded rect on macOS 13–15.
    /// Secondary action: glass button on macOS 26, default below.
    @ViewBuilder
    private var allowButton: some View {
        let button = Button(L("onboarding.permission.allow")) {
            AccessibilityPermission.openSystemSettings()
        }
        if #available(macOS 26, *) {
            button.buttonStyle(.glass)
        } else {
            button
        }
    }

    /// Primary CTA: prominent glass on macOS 26, default large button below.
    @ViewBuilder
    private var startButton: some View {
        let button = Button(action: finish) {
            Text(L("onboarding.start")).frame(maxWidth: .infinity)
        }
        .keyboardShortcut(.defaultAction)
        .controlSize(.large)
        if #available(macOS 26, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button
        }
    }

    /// A single key chip: glass capsule on macOS 26, the original tinted
    /// rounded rect on macOS 13–15.
    @ViewBuilder
    private func chipLabel(_ keys: String) -> some View {
        let label = Text(keys)
            .font(.system(.body, design: .rounded).weight(.semibold))
            .frame(minWidth: 56)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        if #available(macOS 26, *) {
            label.glassEffect(.regular, in: Capsule())
        } else {
            label.background(
                RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15))
            )
        }
    }

    @ViewBuilder
    private var permissionRow: some View {
        if accessibilityGranted {
            Label(L("onboarding.permission.granted"), systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else {
            VStack(spacing: 8) {
                Label(L("onboarding.permission.needed"), systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(L("onboarding.permission.detail"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                allowButton
            }
        }
    }

    private func finish() {
        stopPolling()
        onFinish()
    }

    /// Reflect a grant made in System Settings without needing a relaunch.
    private func startPolling() {
        accessibilityGranted = AccessibilityPermission.isGranted
        let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in accessibilityGranted = AccessibilityPermission.isGranted }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
