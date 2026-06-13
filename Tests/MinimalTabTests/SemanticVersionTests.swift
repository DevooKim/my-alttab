import Foundation
import MinimalTabCore

func runSemanticVersionTests() {
    expectEqual(SemanticVersion("1.2.3"), SemanticVersion(major: 1, minor: 2, patch: 3), "parses x.y.z")
    expectEqual(SemanticVersion("v0.2.0"), SemanticVersion(major: 0, minor: 2, patch: 0), "strips leading v")
    expectEqual(SemanticVersion("1.2"), SemanticVersion(major: 1, minor: 2, patch: 0), "missing patch defaults to 0")
    expect(SemanticVersion("not.a.version") == nil, "rejects non-numeric")
    expect(SemanticVersion("1.2.3.4") == nil, "rejects too many components")

    expect(SemanticVersion("0.2.0")! > SemanticVersion("0.1.9")!, "minor beats patch")
    expect(SemanticVersion("1.0.0")! > SemanticVersion("0.9.9")!, "major beats minor")
    expect(SemanticVersion("0.2.1")! > SemanticVersion("0.2.0")!, "patch compared")
    expect(!(SemanticVersion("0.2.0")! > SemanticVersion("0.2.0")!), "equal is not greater")

    // Update decision: only a strictly greater remote version is an update.
    expect(SemanticVersion("0.3.0")! > SemanticVersion("0.2.0")!, "newer remote is an update")
    expect(!(SemanticVersion("0.2.0")! > SemanticVersion("0.2.0")!), "same version is not an update")
    expect(!(SemanticVersion("0.1.0")! > SemanticVersion("0.2.0")!), "older remote is not an update")
}
