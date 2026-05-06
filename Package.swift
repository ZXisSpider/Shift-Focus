// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Shift-Focus",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Shift-Focus",
            path: "Sources/Shift-Focus",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
