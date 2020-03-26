// swift-tools-version:5.2
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
        .target(name: "Conbini", dependencies: [], path: "sources/Conbini"),
        .target(name: "ConbiniForTesting", dependencies: [.target(name: "Conbini")], path: "sources/Testing"),
        .testTarget(name: "ConbiniTests", dependencies: ["Conbini"], path: "tests/ConbiniTests"),
        .testTarget(name: "ConbiniForTestingTests", dependencies: ["ConbiniForTesting"], path: "tests/TestingTests")
    ]
)
