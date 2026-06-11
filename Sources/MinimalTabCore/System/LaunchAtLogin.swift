import ServiceManagement
import Foundation

/// SMAppService only works when running from a real .app bundle
/// (dist/MinimalTab.app), not via `swift run`.
public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func set(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MinimalTab: launch-at-login change failed: \(error)")
        }
    }
}
