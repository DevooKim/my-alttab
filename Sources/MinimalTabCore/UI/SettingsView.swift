import SwiftUI
import AppKit

public struct SettingsView: View {
    // PRD 3.B: @AppStorage persistence; key shared with Preferences.
    @AppStorage(Preferences.Key.includeMinimized) private var includeMinimized = true
    @State private var globalShortcut = Preferences.shared.globalShortcut
    @State private var sameAppShortcut = Preferences.shared.sameAppShortcut
    @State private var settingsKey = Preferences.shared.settingsKey
    @State private var reverseKey = Preferences.shared.reverseKey
    @State private var quickCloseKey = Preferences.shared.quickCloseKey
    @State private var quickQuitKey = Preferences.shared.quickQuitKey
    @State private var blacklist = Preferences.shared.blacklistedBundleIDs
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    @AppStorage(Preferences.Key.listSize) private var listSizeRaw = ListSize.medium.rawValue
    @AppStorage(Preferences.Key.highlightStyle) private var highlightStyleRaw = HighlightStyle.fill.rawValue
    @State private var showAllSpaces = Preferences.shared.showAllSpaces

    public init() {}

    public var body: some View {
        TabView {
            generalTab
                .tabItem { Label("일반", systemImage: "gearshape") }
            uiTab
                .tabItem { Label("UI", systemImage: "paintbrush") }
            aboutTab
                .tabItem { Label("정보", systemImage: "info.circle") }
        }
        .frame(width: 460)
        .padding(.top, 8)
    }

    private var aboutTab: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            Text("My AltTab")
                .font(.title2.bold())
            Text("버전 \(Self.bundleString("CFBundleShortVersionString")) (빌드 \(Self.bundleString("CFBundleVersion")))")
                .foregroundColor(.secondary)
            Link("github.com/DevooKim/my-alttab",
                 destination: URL(string: "https://github.com/DevooKim/my-alttab")!)
            Text(Self.bundleString("NSHumanReadableCopyright"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    /// Info.plist values are absent when running unbundled (`swift run`).
    private static func bundleString(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "dev"
    }

    private var uiTab: some View {
        Form {
            Section("전환 목록") {
                Picker("목록 크기", selection: $listSizeRaw) {
                    ForEach(ListSize.allCases, id: \.rawValue) { size in
                        Text(size.label).tag(size.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Picker("선택 표시 스타일", selection: $highlightStyleRaw) {
                    ForEach(HighlightStyle.allCases, id: \.rawValue) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("모든 Space의 창 표시", isOn: $showAllSpaces)
            } header: {
                Text("Space")
            } footer: {
                Text("다른 Space에 있는 창도 목록에 표시합니다. 그 창들의 제목을 읽으려면 화면 기록 권한이 필요하며, 권한이 없으면 앱 이름만 표시됩니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: showAllSpaces) { on in
            Preferences.shared.showAllSpaces = on
            // Ask for Screen Recording only when turning the feature ON and
            // it isn't already granted. The prompt polls for the grant and
            // relaunches the app so the permission takes effect.
            if on && !ScreenRecordingPermission.isGranted {
                ScreenRecordingPermission.explainAndPrompt()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var generalTab: some View {
        Form {
            Section("단축키") {
                ShortcutRecorderView(label: "전체 윈도우 전환 (Global Switch)", shortcut: $globalShortcut)
                ShortcutRecorderView(label: "현재 앱 윈도우 전환 (Same-App Switch)", shortcut: $sameAppShortcut)
                SingleKeyRecorderView(label: "역방향 이동 키 (리스트 열린 상태)", keyCode: $reverseKey)
                SingleKeyRecorderView(label: "설정 창 열기 키 (리스트 열린 상태)", keyCode: $settingsKey)
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
                    // Only this list scrolls; the rest of the form stays put.
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(blacklist, id: \.self) { bundleID in
                                HStack {
                                    Text(displayName(for: bundleID))
                                    Text(bundleID).font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Button("제거") { blacklist.removeAll { $0 == bundleID } }
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                    .frame(height: 150)
                }
                HStack {
                    Menu("실행 중인 앱에서 추가…") {
                        ForEach(addableApps(), id: \.self) { bundleID in
                            Button(displayName(for: bundleID)) { blacklist.append(bundleID) }
                        }
                    }
                    Spacer()
                    Button("기본값 복원") { blacklist = Preferences.defaultBlacklist }
                        .disabled(blacklist == Preferences.defaultBlacklist)
                }
            }
            Section("일반") {
                Toggle("로그인 시 자동 실행 (Launch at login)", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: globalShortcut) { Preferences.shared.globalShortcut = $0 }
        .onChange(of: sameAppShortcut) { Preferences.shared.sameAppShortcut = $0 }
        .onChange(of: settingsKey) { Preferences.shared.settingsKey = $0 }
        .onChange(of: reverseKey) { Preferences.shared.reverseKey = $0 }
        .onChange(of: quickCloseKey) { Preferences.shared.quickCloseKey = $0 }
        .onChange(of: quickQuitKey) { Preferences.shared.quickQuitKey = $0 }
        .onChange(of: blacklist) { Preferences.shared.blacklistedBundleIDs = $0 }
        .onChange(of: launchAtLogin) { LaunchAtLogin.set(enabled: $0) }
    }

    /// Regular running apps not yet excluded (prefix entries respected).
    private func addableApps() -> [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { !WindowEnumerator.isExcluded($0, blacklist: blacklist) }
            .sorted { displayName(for: $0) < displayName(for: $1) }
    }

    /// Friendly names for the default exclusions, which are usually not
    /// running and therefore can't be resolved via NSWorkspace.
    private static let knownNames: [String: String] = [
        "com.McAfee.McAfeeSafariHost": "McAfee Safari Host",
        "com.apple.ScreenSharing": "화면 공유 (Screen Sharing)",
        "com.microsoft.rdc.macos": "Microsoft Remote Desktop",
        "com.teamviewer.TeamViewer": "TeamViewer",
        "org.virtualbox.app.VirtualBoxVM": "VirtualBox VM",
        "com.parallels.": "Parallels (전체)",
        "com.citrix.XenAppViewer": "Citrix XenApp Viewer",
        "com.citrix.receiver.icaviewer.mac": "Citrix Receiver",
        "com.nicesoftware.dcvviewer": "NICE DCV Viewer",
        "com.vmware.fusion": "VMware Fusion",
        "com.utmapp.UTM": "UTM",
    ]

    private func displayName(for bundleID: String) -> String {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?.localizedName
            ?? Self.knownNames[bundleID]
            ?? bundleID
    }
}
