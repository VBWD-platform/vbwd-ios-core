// swift-tools-version:6.0
import PackageDescription

// NOTE: Tests run via a dependency-free harness (VBWDCoreTestKit) invoked as
// an executable:
//     swift run VBWDCoreTestsRunner
// Named test cases and Red/Green/Refactor are preserved. Under full Xcode the
// same suites can additionally be wrapped in an XCTest target unchanged.

let package = Package(
    name: "VBWDCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "VBWDCore", targets: ["VBWDCore"]),
    ],
    targets: [
        .target(
            name: "VBWDCore",
            path: "Sources/VBWDCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "VBWDCoreTestKit",
            path: "Sources/VBWDCoreTestKit",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "VBWDCoreTestsRunner",
            dependencies: ["VBWDCore", "VBWDCoreTestKit"],
            path: "Sources/VBWDCoreTestsRunner",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ],
    // Swift 6 language mode with strict concurrency checking enabled.
    // MainActor isolation properly enforced for UI components.
    swiftLanguageModes: [.v6]
)
