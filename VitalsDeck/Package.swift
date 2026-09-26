// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VitalsDeck",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VitalsDeck", targets: ["VitalsDeck"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VitalsDeck",
            path: "Sources/VitalsDeck",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
