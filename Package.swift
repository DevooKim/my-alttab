// swift-tools-version: 5.10
import PackageDescription

// NOTE: This machine has only Command Line Tools (no Xcode), so XCTest is
// unavailable. Tests live in an executable runner target instead:
//   swift run minimaltab-tests
let package = Package(
    name: "MinimalTab",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MinimalTabCore",
            path: "Sources/MinimalTabCore"
        ),
        .executableTarget(
            name: "MinimalTab",
            dependencies: ["MinimalTabCore"],
            path: "Sources/MinimalTabApp"
        ),
        .executableTarget(
            name: "minimaltab-tests",
            dependencies: ["MinimalTabCore"],
            path: "Tests/MinimalTabTests"
        ),
    ]
)
