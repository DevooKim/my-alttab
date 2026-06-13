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

            VStack(alignment: .leading, spacing: 8) {
                ForEach(shortcuts, id: \.keys) { item in
                    HStack(spacing: 12) {
                        Text(item.keys)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .frame(minWidth: 56)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.15))
                            )
                        Text(item.label)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 8)

            Divider()

            permissionRow

            Button(action: finish) {
                Text(L("onboarding.start")).frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 420)
        .onAppear(perform: startPolling)
        .onDisappear(perform: stopPolling)
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
                Button(L("onboarding.permission.allow")) {
                    AccessibilityPermission.openSystemSettings()
                }
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
