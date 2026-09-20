// swift-tools-version: 5.9
import PackageDescription

// The watch app's logic without any UI or WatchConnectivity, so it can be
// tested on the Mac with `swift test`. The Xcode project compiles the same
// files straight into the watch app target.
let package = Package(
  name: "HermesWatchCore",
  platforms: [.macOS(.v14), .watchOS(.v10)],
  products: [.library(name: "HermesWatchCore", targets: ["HermesWatchCore"])],
  targets: [
    .target(name: "HermesWatchCore", path: "Core"),
    .testTarget(
      name: "HermesWatchCoreTests",
      dependencies: ["HermesWatchCore"],
      path: "Tests/HermesWatchCoreTests"
    ),
  ]
)
