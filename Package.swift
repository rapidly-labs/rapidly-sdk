// swift-tools-version:5.9
// Rapidly SDK — https://rapidly.io/docs
//
// The Rapidly SDK ships in two parts that compose into a single
// `import RapidlyEngine` for SwiftPM consumers:
//
//   1. `RapidlyEngineC` — binary xcframework holding the C engine and
//      the Obj-C++ adapter. Module name ends in "C" so it does not
//      collide with the Swift target name.
//
//   2. `RapidlyEngine` — Swift source target wrapping the adapter in
//      a Swift-native class. `@_exported import RapidlyEngineC` makes
//      the binary surface visible through the same import.

import PackageDescription

let package = Package(
    name: "Rapidly SDK",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "RapidlySDK",
            targets: ["RapidlyEngine"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "RapidlyEngineC",
            url: "https://github.com/rapidly-labs/rapidly-sdk/releases/download/v1.0.1/RapidlyEngine.xcframework.zip",
            checksum: "658f52f8c140cf52e2a8471dc1b407b37216454560e9ea0ec6e4da48153d4c76"
        ),
        .target(
            name: "RapidlyEngine",
            dependencies: ["RapidlyEngineC"],
            path: "bindings/swift/Sources/RapidlyEngine"
        ),
    ]
)
