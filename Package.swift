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
        .executableTarget(
            name: "ChaoticFingers",
            path: ".",
            exclude: ["Chaotic Fingers.app", "dist", "package.sh", "README.md", "icon.png"],
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
        )
    ]
)
