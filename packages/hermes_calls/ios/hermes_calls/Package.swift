// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "hermes_calls",
  platforms: [.iOS("26.0")],
  products: [.library(name: "hermes-calls", targets: ["hermes_calls"])],
  dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
  targets: [.target(name: "hermes_calls", dependencies: [
    .product(name: "FlutterFramework", package: "FlutterFramework")
  ])]
)
