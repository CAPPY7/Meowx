// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeowxCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MeowxCore", targets: ["MeowxCore"]),
    ],
    targets: [
        .target(name: "MeowxCore"),
        .testTarget(name: "MeowxCoreTests", dependencies: ["MeowxCore"]),
    ]
)
