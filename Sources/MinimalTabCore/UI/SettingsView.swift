import SwiftUI
import AppKit

/// Window-background blur for the settings window. Pairs with the
/// `fullSizeContentView` + transparent titlebar so the chrome and content
/// share one translucent surface.
private struct WindowMaterialBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .windowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

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
    @State private var languageOverride = Preferences.shared.languageOverride

    public init() {}

    public var body: some View {
        TabView {
            generalTab
                .tabItem { Label(L("settings.tab.general"), systemImage: "gearshape") }
            uiTab
                .tabItem { Label(L("settings.tab.ui"), systemImage: "paintbrush") }
            aboutTab
                .tabItem { Label(L("settings.tab.about"), systemImage: "info.circle") }
        }
        .frame(minWidth: 460, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        // Fills the transparent titlebar region (fullSizeContentView) so the
        // window reads as one continuous translucent surface.
        .background(WindowMaterialBackground())
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                Text("My AltTab")
                    .font(.title2.bold())
                Text(String(format: L("settings.about.version"), Self.bundleString("CFBundleShortVersionString"), Self.bundleString("CFBundleVersion")))
                    .foregroundColor(.secondary)
                Button(L("settings.about.checkForUpdates")) {
                    Updater.checkForUpdates(silent: false)
                }
                .glassButtonStyle()
                .padding(.top, 4)
                Link("github.com/DevooKim/my-alttab",
                     destination: URL(string: "https://github.com/DevooKim/my-alttab")!)
                Text(Self.bundleString("NSHumanReadableCopyright"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            // App-info card: Liquid Glass panel on macOS 26, subtle material below.
            .glassEffectWithFallback(
                in: RoundedRectangle(cornerRadius: 20, style: .continuous),
                fallbackMaterial: .regularMaterial
            )
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    /// Info.plist values are absent when running unbundled (`swift run`).
    private static func bundleString(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "dev"
    }

    private var uiTab: some View {
        Form {
            Section(L("settings.ui.listSection")) {
                Picker(L("settings.ui.listSize"), selection: $listSizeRaw) {
                    ForEach(ListSize.allCases, id: \.rawValue) { size in
                        Text(size.label).tag(size.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Picker(L("settings.ui.highlightStyle"), selection: $highlightStyleRaw) {
                    ForEach(HighlightStyle.allCases, id: \.rawValue) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Picker(L("settings.language"), selection: $languageOverride) {
                    Text(L("settings.language.system")).tag("system")
                    Text(L("settings.language.ko")).tag("ko")
                    Text(L("settings.language.en")).tag("en")
                }
            } footer: {
                Text(L("settings.language.restartNote"))
                    .font(.caption).foregroundColor(.secondary)
            }
            Section {
                Toggle(L("settings.ui.showAllSpaces"), isOn: $showAllSpaces)
            } header: {
                Text(L("settings.ui.spaceSection"))
            } footer: {
                Text(L("settings.ui.showAllSpaces.footer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: languageOverride) { code in
            Preferences.shared.languageOverride = code
            // A language change re-reads strings app-wide; relaunch so every
            // view rebuilds in the new language.
            ScreenRecordingPermission.relaunch()
        }
        .onChange(of: showAllSpaces) { on in
            Preferences.shared.showAllSpaces = on
            // Ask for Screen Recording only when turning the feature ON and
            // it isn't already granted. The prompt polls for the grant and
            // relaunches the app so the permission takes effect.
            if on && !ScreenRecordingPermission.isGranted {
                ScreenRecordingPermission.explainAndPrompt()
            }
        }
    }

    private var generalTab: some View {
        Form {
            Section(L("settings.shortcutSection")) {
                ShortcutRecorderView(label: L("settings.shortcut.global"), shortcut: $globalShortcut)
                ShortcutRecorderView(label: L("settings.shortcut.sameApp"), shortcut: $sameAppShortcut)
                SingleKeyRecorderView(label: L("settings.shortcut.reverse"), keyCode: $reverseKey)
                SingleKeyRecorderView(label: L("settings.shortcut.openSettings"), keyCode: $settingsKey)
            }
            Section(L("settings.quickSection")) {
                SingleKeyRecorderView(label: L("settings.quick.close"), keyCode: $quickCloseKey)
                SingleKeyRecorderView(label: L("settings.quick.quit"), keyCode: $quickQuitKey)
            }
            Section(L("settings.listSection")) {
                Toggle(L("settings.includeMinimized"), isOn: $includeMinimized)
            }
            Section(L("settings.exclusionSection")) {
                if blacklist.isEmpty {
                    Text(L("settings.exclusion.empty")).foregroundColor(.secondary)
                } else {
                    // Only this list scrolls; the rest of the form stays put.
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(blacklist, id: \.self) { bundleID in
                                HStack {
                                    Text(displayName(for: bundleID))
                                    Text(bundleID).font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Button(L("settings.exclusion.remove")) { blacklist.removeAll { $0 == bundleID } }
                                        .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                if bundleID != blacklist.last { Divider() }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 150)
                    // Inset glass card around the exclusion list.
                    .glassEffectWithFallback(
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                        fallbackMaterial: .thinMaterial
                    )
                }
                HStack {
                    Menu(L("settings.exclusion.addRunning")) {
                        ForEach(addableApps(), id: \.self) { bundleID in
                            Button(displayName(for: bundleID)) { blacklist.append(bundleID) }
                        }
                    }
                    .fixedSize()
                    Spacer()
                    Button(L("settings.exclusion.restoreDefaults")) { blacklist = Preferences.defaultBlacklist }
                        .glassButtonStyle()
                        .disabled(blacklist == Preferences.defaultBlacklist)
                }
            }
            Section(L("settings.generalSection")) {
                Toggle(L("settings.launchAtLogin"), isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
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
        "com.microsoft.rdc.macos": "Microsoft Remote Desktop",
        "com.teamviewer.TeamViewer": "TeamViewer",
        "org.virtualbox.app.VirtualBoxVM": "VirtualBox VM",
        "com.citrix.XenAppViewer": "Citrix XenApp Viewer",
        "com.citrix.receiver.icaviewer.mac": "Citrix Receiver",
        "com.nicesoftware.dcvviewer": "NICE DCV Viewer",
        "com.vmware.fusion": "VMware Fusion",
        "com.utmapp.UTM": "UTM",
    ]

    /// Localized friendly names (can't live in the static dict above).
    private static func localizedName(_ bundleID: String) -> String? {
        switch bundleID {
        case "com.apple.ScreenSharing": return L("app.screenSharing")
        case "com.parallels.": return L("app.parallels")
        default: return knownNames[bundleID]
        }
    }

    private func displayName(for bundleID: String) -> String {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?.localizedName
            ?? Self.localizedName(bundleID)
            ?? bundleID
    }
}
