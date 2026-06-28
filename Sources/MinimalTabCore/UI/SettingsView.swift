import SwiftUI
import AppKit

/// Window-background blur for the settings window. Pairs with the
/// `fullSizeContentView` + transparent titlebar so the chrome and content
/// share one translucent surface.
private struct WindowMaterialBackground: NSViewRepresentable {
    // .hudWindow is one of the most translucent system materials — lets more
    // of the desktop/windows behind show through than .windowBackground.
    var material: NSVisualEffectView.Material = .hudWindow
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

/// Makes the host window's titlebar (where SwiftUI draws the TabView's tab bar)
/// transparent and extends content under it, so the tab-bar strip reads as the
/// translucent window material instead of an opaque bar. macOS draws the tab
/// bar background as part of the titlebar region; this is the only lever to it
/// without private API.
private struct TransparentTitlebar: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.apply(to: view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.apply(to: nsView.window) }
    }

    private static func apply(to window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true

        // The opaque tab-bar strip is the titlebar region: SwiftUI's TabView
        // draws its tab bar as a toolbar inside NSTitlebarContainerView, whose
        // background is painted by an NSVisualEffectView + a dark solid
        // fill view. Find that container in the window's theme frame and clear
        // every background/effect view inside it so the strip shows the window
        // material behind it. (No public API reaches the titlebar background.)
        guard let themeFrame = window.contentView?.superview else { return }
        for sub in themeFrame.subviews
        where String(describing: type(of: sub)) == "NSTitlebarContainerView" {
            clearTitlebarBackground(in: sub)
        }
    }

    /// Recursively neutralize anything in the titlebar container that paints an
    /// opaque background: visual-effect views and the solid fill/backdrop
    /// layers. Toolbar item views (the tab buttons themselves) are left alone.
    private static func clearTitlebarBackground(in view: NSView) {
        for sub in view.subviews {
            let cls = String(describing: type(of: sub))
            if let effect = sub as? NSVisualEffectView {
                effect.alphaValue = 0
            } else if cls == "NSTitlebarBackgroundView"
                        || cls.contains("BackdropView")
                        || cls.contains("FillColorView")
                        || cls.contains("ScrollPocket")
                        || cls.contains("ContentBackgroundView") {
                sub.alphaValue = 0
            }
            // Don't recurse into the toolbar (keeps the tab buttons visible).
            if cls != "NSToolbarView" {
                clearTitlebarBackground(in: sub)
            }
        }
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
    @AppStorage(Preferences.Key.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Preferences.Key.skipSpaceSwitchAnimation) private var skipSpaceSwitchAnimation = false
    @State private var showAllSpaces = Preferences.shared.showAllSpaces

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
        .frame(minWidth: 460, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        // Fills the transparent titlebar region (fullSizeContentView) so the
        // window reads as one continuous translucent surface. A faint accent
        // tint over the material gives the content area below the tab bar a
        // subtle colour without touching the system-drawn tab bar itself.
        .background {
            WindowMaterialBackground()
        }
        // Make the titlebar/tab-bar strip transparent so it shows the window
        // material instead of an opaque bar.
        .background(TransparentTitlebar())
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
                Link("GitHub",
                     destination: URL(string: "https://github.com/DevooKim/my-alttab")!)
                Text(Self.bundleString("NSHumanReadableCopyright"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
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
                Toggle(L("settings.ui.showMenuBarIcon"), isOn: $showMenuBarIcon)
            } header: {
                Text(L("settings.ui.menuBarSection"))
            } footer: {
                Text(L("settings.ui.showMenuBarIcon.footer"))
                    .font(.caption).foregroundColor(.secondary)
            }
            Section {
                Toggle(L("settings.ui.showAllSpaces"), isOn: $showAllSpaces)
                Toggle(L("settings.ui.skipSpaceAnimation"), isOn: $skipSpaceSwitchAnimation)
            } header: {
                Text(L("settings.ui.spaceSection"))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("settings.ui.showAllSpaces.footer"))
                    Text(L("settings.ui.skipSpaceAnimation.footer"))
                }
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
