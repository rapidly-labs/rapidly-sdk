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
    name: "RapidlyEngine",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "RapidlyEngine",
            targets: ["RapidlyEngine"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "RapidlyEngineC",
            url: "https://github.com/rapidly-labs/rapidly-sdk/releases/download/v1.0.0/RapidlyEngine.xcframework.zip",
            checksum: "5215da20bb2f5d23cd707691bb302d64a14bfec76f9499c92187ba88518593d6"
        ),
        .target(
            name: "RapidlyEngine",
            dependencies: ["RapidlyEngineC"],
            path: "bindings/swift/Sources/RapidlyEngine"
        ),
    ]
)
