// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "T1Core",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "T1Protocol", targets: ["T1Protocol"]),
    .library(name: "T1Gestures", targets: ["T1Gestures"]),
  ],
  targets: [
    .target(name: "T1Protocol"),
    .target(name: "T1Gestures", dependencies: ["T1Protocol"]),
    .testTarget(name: "T1ProtocolTests", dependencies: ["T1Protocol"]),
    .testTarget(name: "T1GestureTests", dependencies: ["T1Gestures", "T1Protocol"]),
  ]
)
