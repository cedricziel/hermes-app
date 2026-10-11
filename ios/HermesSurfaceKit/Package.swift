// swift-tools-version: 5.9
import PackageDescription

// What the iOS system surfaces (widgets, App Intents and controls) share: the
// reader of the app's surface snapshot, the logic of what each widget shows and
// the intents that open the app, without any UI, so it can be tested on the Mac
// with `swift test`.
// The Xcode project compiles the same files straight into its targets.
let package = Package(
  name: "HermesSurfaceKit",
  platforms: [.macOS("26.0"), .iOS("26.0")],
  products: [.library(name: "HermesSurfaceKit", targets: ["HermesSurfaceKit"])],
  targets: [
    .target(name: "HermesSurfaceKit", path: "Sources/HermesSurfaceKit"),
    .testTarget(
      name: "HermesSurfaceKitTests",
      dependencies: ["HermesSurfaceKit"],
      path: "Tests/HermesSurfaceKitTests"
    ),
  ]
)
