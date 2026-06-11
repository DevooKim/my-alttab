import SwiftUI

public struct SettingsView: View {
    // PRD 3.B: @AppStorage persistence; key shared with Preferences.
    @AppStorage(Preferences.Key.includeMinimized) private var includeMinimized = true
    @State private var globalShortcut = Preferences.shared.globalShortcut
    @State private var sameAppShortcut = Preferences.shared.sameAppShortcut
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    public init() {}

    public var body: some View {
        Form {
            Section("단축키") {
                ShortcutRecorderView(label: "전체 윈도우 전환 (Global Switch)", shortcut: $globalShortcut)
                ShortcutRecorderView(label: "현재 앱 윈도우 전환 (Same-App Switch)", shortcut: $sameAppShortcut)
            }
            Section("목록") {
                Toggle("최소화된 윈도우 목록에 포함하기", isOn: $includeMinimized)
            }
            Section("일반") {
                Toggle("로그인 시 자동 실행 (Launch at login)", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: globalShortcut) { Preferences.shared.globalShortcut = $0 }
        .onChange(of: sameAppShortcut) { Preferences.shared.sameAppShortcut = $0 }
        .onChange(of: launchAtLogin) { LaunchAtLogin.set(enabled: $0) }
    }
}
