import AppKit

/// Standard About panel: bundle icon, name, version, and copyright come from
/// Info.plist; credits add the GitHub link. Relocated from the old
/// `StatusBarController` so it can be invoked from the SwiftUI `MenuBarExtra`.
@MainActor
public enum AboutPanel {
    public static func present() {
        // An LSUIElement app must explicitly activate to bring the panel forward.
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
