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
        alert.messageText = "손쉬운 사용 권한이 필요합니다"
        alert.informativeText = """
        My AltTab은 다른 앱의 윈도우 목록을 가져오고 포커스를 제어하기 위해 \
        손쉬운 사용(Accessibility) 권한이 필요합니다.

        시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 My AltTab을 허용한 뒤 앱을 다시 실행해 주세요.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}
