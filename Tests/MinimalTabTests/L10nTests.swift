import Foundation
import MinimalTabCore

func runL10nTests() {
    // A known key resolves (not equal to the key itself = found in .strings).
    let s = L("onboarding.start")
    expect(s != "onboarding.start", "known key resolves to a localized value")

    // A missing key falls back to the key string.
    expectEqual(L("this.key.does.not.exist"), "this.key.does.not.exist",
                "missing key falls back to the key")

    // en and ko .strings must share the exact same key set (catches a
    // translation gap before it ships).
    if let enKeys = L10n.keys(forLanguage: "en"), let koKeys = L10n.keys(forLanguage: "ko") {
        let onlyEn = enKeys.subtracting(koKeys)
        let onlyKo = koKeys.subtracting(enKeys)
        expect(onlyEn.isEmpty, "keys present in en but missing in ko: \(onlyEn.sorted())")
        expect(onlyKo.isEmpty, "keys present in ko but missing in en: \(onlyKo.sorted())")
        expect(!enKeys.isEmpty, "en strings file has keys")
    } else {
        expect(false, "could not load both .strings files from the resource bundle")
    }
}
