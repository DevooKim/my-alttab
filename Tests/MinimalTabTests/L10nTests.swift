import Foundation
import MinimalTabCore

func runL10nTests() {
    // A known key resolves to its hardcoded Korean string (not the key itself).
    let s = L("onboarding.start")
    expect(s != "onboarding.start", "known key resolves to a localized value")
    expectEqual(s, "시작하기", "known key resolves to the Korean string")

    // A missing key falls back to the key string.
    expectEqual(L("this.key.does.not.exist"), "this.key.does.not.exist",
                "missing key falls back to the key")
}
