import Foundation

/// Localized-string lookup, honoring an optional manual language override
/// (Preferences.languageOverride). With "system" it uses Bundle.module's
/// default behavior (system locale); with "ko"/"en" it loads that .lproj
/// bundle directly so the choice applies regardless of system language.
public enum L10n {
    /// Cached override bundle, rebuilt when the override changes.
    private static var cachedCode: String?
    private static var cachedBundle: Bundle?

    public static func string(_ key: String) -> String {
        let bundle = overrideBundle() ?? .module
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Key set of a bundled .strings file (for tests / tooling).
    public static func keys(forLanguage code: String) -> Set<String>? {
        guard let path = Bundle.module.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path),
              let url = bundle.url(forResource: "Localizable", withExtension: "strings"),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else {
            return nil
        }
        return Set(dict.keys)
    }

    private static func overrideBundle() -> Bundle? {
        let code = Preferences.shared.languageOverride
        guard code == "ko" || code == "en" else { return nil }
        if code == cachedCode, let cached = cachedBundle { return cached }
        guard let path = Bundle.module.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        cachedCode = code
        cachedBundle = bundle
        return bundle
    }
}

/// Shorthand used throughout the UI.
public func L(_ key: String) -> String { L10n.string(key) }
