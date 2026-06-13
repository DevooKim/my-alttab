import AppKit
import CoreGraphics

/// Screen Recording permission — required ONLY for the optional
/// "show windows from all Spaces" feature, to read titles of windows on
/// inactive Spaces via kCGWindowName. The app never requests this unless
/// the user turns that setting on.
enum ScreenRecordingPermission {
    /// `CGPreflightScreenCaptureAccess` checks without prompting.
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system prompt (and registers the app in the list).
    /// Returns the immediate result; a fresh grant only takes effect after
    /// the app restarts, which macOS enforces.
    @discardableResult
    static func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Alert explaining why the permission is needed and linking to the
    /// System Settings pane. Once the grant lands (polled), the app
    /// relaunches itself — Screen Recording only takes effect on restart.
    @MainActor
    static func explainAndPrompt() {
        let alert = NSAlert()
        alert.messageText = "화면 기록 권한이 필요합니다"
        alert.informativeText = """
        다른 Space(데스크탑)에 있는 창의 제목을 읽으려면 화면 기록 권한이 필요합니다. \
        이 권한은 '모든 Space의 창 표시' 기능에만 사용되며, 창 제목 외의 화면 내용은 캡처하지 않습니다.

        시스템 설정에서 My AltTab을 허용하면 앱이 자동으로 다시 실행됩니다.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")

        request()
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            NSWorkspace.shared.open(url)
            waitForGrantThenRelaunch()
        }
    }

    /// Polls until the permission is granted (or the user gives up), then
    /// relaunches so the new permission takes effect.
    @MainActor
    private static func waitForGrantThenRelaunch() {
        guard !isGranted else { return }
        var elapsed = 0.0
        let timer = Timer(timeInterval: 1.0, repeats: true) { timer in
            elapsed += 1.0
            if isGranted {
                timer.invalidate()
                relaunch()
            } else if elapsed >= 120 { // give up after 2 minutes
                timer.invalidate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Launches a fresh instance of the bundle and terminates this one.
    /// Only works from a real .app bundle (no-op-ish under `swift run`).
    @MainActor
    static func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
