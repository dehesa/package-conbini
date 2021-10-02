// swift-tools-version:5.1
import PackageDescription

var package = Package(
  name: "Conbini",
  platforms: [
    .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
  ],
  products: [
    .library(name: "Conbini", targets: ["Conbini"]),
    .library(name: "ConbiniForTesting", targets: ["ConbiniForTesting"])
  ],
  dependencies: [],
  targets: [
    .target(name: "Conbini", path: "sources/runtime"),
    .target(name: "ConbiniForTesting", path: "sources/testing"),
    .testTarget(name: "ConbiniTests", dependencies: ["Conbini"], path: "tests/runtime"),
    .testTarget(name: "ConbiniForTestingTests", dependencies: ["Conbini", "ConbiniForTesting"], path: "tests/testing"),
  ]
)
