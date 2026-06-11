import SwiftUI
import AppKit

public struct SettingsView: View {
    // PRD 3.B: @AppStorage persistence; key shared with Preferences.
    @AppStorage(Preferences.Key.includeMinimized) private var includeMinimized = true
    @State private var globalShortcut = Preferences.shared.globalShortcut
    @State private var sameAppShortcut = Preferences.shared.sameAppShortcut
    @State private var quickCloseKey = Preferences.shared.quickCloseKey
    @State private var quickQuitKey = Preferences.shared.quickQuitKey
    @State private var blacklist = Preferences.shared.blacklistedBundleIDs
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    public init() {}

    public var body: some View {
        Form {
            Section("단축키") {
                ShortcutRecorderView(label: "전체 윈도우 전환 (Global Switch)", shortcut: $globalShortcut)
                ShortcutRecorderView(label: "현재 앱 윈도우 전환 (Same-App Switch)", shortcut: $sameAppShortcut)
                LabeledContent("역방향 이동") {
                    Text("⇧ + 전환 키").foregroundColor(.secondary)
                }
            }
            Section("Quick Actions (리스트가 열린 상태에서)") {
                SingleKeyRecorderView(label: "선택한 창 닫기", keyCode: $quickCloseKey)
                SingleKeyRecorderView(label: "선택한 앱 종료", keyCode: $quickQuitKey)
            }
            Section("목록") {
                Toggle("최소화된 윈도우 목록에 포함하기", isOn: $includeMinimized)
            }
            Section("제외 앱") {
                if blacklist.isEmpty {
                    Text("제외된 앱 없음").foregroundColor(.secondary)
                } else {
                    ForEach(blacklist, id: \.self) { bundleID in
                        HStack {
                            Text(displayName(for: bundleID))
                            Text(bundleID).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Button("제거") { blacklist.removeAll { $0 == bundleID } }
                        }
                    }
                }
                Menu("실행 중인 앱에서 추가…") {
                    ForEach(addableApps(), id: \.self) { bundleID in
                        Button(displayName(for: bundleID)) { blacklist.append(bundleID) }
                    }
                }
            }
            Section("일반") {
                Toggle("로그인 시 자동 실행 (Launch at login)", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: globalShortcut) { Preferences.shared.globalShortcut = $0 }
        .onChange(of: sameAppShortcut) { Preferences.shared.sameAppShortcut = $0 }
        .onChange(of: quickCloseKey) { Preferences.shared.quickCloseKey = $0 }
        .onChange(of: quickQuitKey) { Preferences.shared.quickQuitKey = $0 }
        .onChange(of: blacklist) { Preferences.shared.blacklistedBundleIDs = $0 }
        .onChange(of: launchAtLogin) { LaunchAtLogin.set(enabled: $0) }
    }

    /// Regular running apps not yet excluded.
    private func addableApps() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { !blacklist.contains($0) }
            .sorted { displayName(for: $0) < displayName(for: $1) }
    }

    private func displayName(for bundleID: String) -> String {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?.localizedName ?? bundleID
    }
}
