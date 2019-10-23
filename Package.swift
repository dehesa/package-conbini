// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Conbini",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(name: "Conbini", targets: ["Conbini"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Conbini", dependencies: []),
        .testTarget(name: "ConbiniTests", dependencies: ["Conbini"])
    ]
)
