// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "BrightBar",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "BrightBar", targets: ["BrightBarApp"]),
    .executable(name: "BrightBarTests", targets: ["BrightBarTests"]),
  ],
  targets: [
    .target(
      name: "BrightBarCore",
      path: "Sources/BrightBarCore"
    ),
    .executableTarget(
      name: "BrightBarApp",
      dependencies: ["BrightBarCore"],
      path: "Sources/BrightBarApp",
      resources: [.process("Resources")]
    ),
    .executableTarget(
      name: "BrightBarTests",
      dependencies: ["BrightBarCore"],
      path: "Tests/BrightBarCoreTests"
    ),
  ]
)
