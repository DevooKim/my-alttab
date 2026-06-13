import AppKit

@MainActor
public final class StatusBarController {
    private let statusItem: NSStatusItem
    private let onSettings: () -> Void

    public init(onSettings: @escaping () -> Void) {
        self.onSettings = onSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.stack",
            accessibilityDescription: "My AltTab"
        )

        let menu = NSMenu()
        let aboutItem = NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())
        let updateItem = NSMenuItem(title: L("menu.checkForUpdates"), action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit My AltTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        onSettings()
    }

    @objc private func checkForUpdates() {
        Updater.checkForUpdates(silent: false)
    }

    /// Standard About panel: bundle icon, name, version, and copyright
    /// come from Info.plist; credits add the GitHub link.
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSMutableAttributedString(string: "GitHub")
        let range = NSRange(location: 0, length: credits.length)
        credits.addAttributes([
            .link: "https://github.com/DevooKim/my-alttab",
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }(),
        ], range: range)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
