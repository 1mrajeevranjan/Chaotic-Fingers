// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChaoticFingers",
    platforms: [
        .macOS(.v14)  // Minimum: macOS 14 Sonoma (@Observable + SMAppService)
    ],
    products: [
        .executable(name: "ChaoticFingers", targets: ["ChaoticFingers"])
    ],
    targets: [
        // Pure gesture/blocking logic, free of AppKit so it can be exercised
        // by the SelfCheck executable.
        .target(name: "ChaoticFingersCore", path: "Core"),

        .executableTarget(
            name: "ChaoticFingers",
            dependencies: ["ChaoticFingersCore"],
            path: ".",
            exclude: [
                "Core",
                "Tests",
                "Chaotic Fingers.app",
                "dist",
                "package.sh",
                "README.md",
                "icon.png",
                "Info.plist"
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        ),

        // `swift run SelfCheck` — assert-based checks for ChaoticFingersCore.
        // XCTest and swift-testing both require Xcode, which this package does
        // not otherwise need, so `swift test` is not usable here.
        .executableTarget(
            name: "SelfCheck",
            dependencies: ["ChaoticFingersCore"],
            path: "Tests/SelfCheck"
        )
    ]
)
