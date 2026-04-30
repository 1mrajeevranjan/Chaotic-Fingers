// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ChaoticFingers",
    platforms: [
        .macOS(.v26)
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
