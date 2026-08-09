// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LogiPetMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LogiPetMac", targets: ["LogiPetMac"])
    ],
    targets: [
        .executableTarget(
            name: "LogiPetMac",
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "LogiPetMacTests",
            dependencies: ["LogiPetMac"]
        )
    ]
)
