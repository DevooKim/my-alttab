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

    private static let shortcuts: [(keys: String, label: String)] = [
        ("⌥⇥", "전체 윈도우 전환"),
        ("⌥`", "현재 앱 윈도우 전환"),
        ("⇧", "역방향 이동 (전환 키와 함께)"),
        ("W / Q", "선택한 창 닫기 / 앱 종료"),
    ]

    public var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("My AltTab")
                .font(.title.bold())
            Text("미리보기 없는 텍스트 기반 윈도우 전환기")
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.shortcuts, id: \.keys) { item in
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
                Text("시작하기").frame(maxWidth: .infinity)
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
            Label("손쉬운 사용 권한 허용됨", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else {
            VStack(spacing: 8) {
                Label("손쉬운 사용 권한이 필요합니다", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("다른 앱의 윈도우 목록을 가져오고 포커스를 제어하려면 권한이 필요합니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("손쉬운 사용 권한 허용") {
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
