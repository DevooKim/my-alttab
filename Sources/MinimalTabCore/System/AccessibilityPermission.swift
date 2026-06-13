import AppKit
import ApplicationServices

public enum AccessibilityPermission {
    public static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// PRD 4.D: on first launch without permission, show an alert that
    /// jumps straight to System Settings > Privacy & Security > Accessibility.
    @MainActor
    public static func promptIfNeeded() {
        guard !isGranted else { return }

        // Also registers the app in the Accessibility list so the user
        // only has to flip the toggle.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = L("accessibility.title")
        alert.informativeText = L("accessibility.detail")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("accessibility.openSettings"))
        alert.addButton(withTitle: L("common.later"))

        if alert.runModal() == .alertFirstButtonReturn {
            openSystemSettings()
        }
    }

    /// Registers the app in the Accessibility list and opens that pane in
    /// System Settings — no alert. Used by the onboarding window's
    /// "권한 허용" button.
    @MainActor
    public static func openSystemSettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
