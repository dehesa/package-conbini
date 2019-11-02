// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Conbini",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(name: "Conbini", targets: ["Conbini"]),
        .library(name: "ConbiniForTesting", targets: ["Conbini", "ConbiniForTesting"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Conbini", dependencies: []),
        .target(name: "ConbiniForTesting", dependencies: [.target(name: "Conbini")], path: "Sources/Testing"),
        .testTarget(name: "ConbiniTests", dependencies: ["Conbini"]),
        .testTarget(name: "ConbiniForTestingTests", dependencies: ["ConbiniForTesting"], path: "Tests/TestingTests")
    ]
)
