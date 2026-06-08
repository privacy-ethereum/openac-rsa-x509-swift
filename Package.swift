// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "OpenACSwift",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "OpenACSwift",
      targets: ["OpenACSwift"]
    )
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "OpenACSwift",
      dependencies: [
        .target(name: "OpenACSwiftBindings"),
        .target(name: "COpenACFFI"),
      ],
      path: "Sources/",
      exclude: ["COpenACFFI"],
      linkerSettings: [
        .linkedLibrary("c++")
      ]
    ),
    // COpenACFFI exposes openac_mobile_appFFI as a real SPM Clang module.
    // Xcode 26+ does not register module maps from binary XCFrameworks
    // containing static libraries, so #if canImport(openac_mobile_appFFI)
    // in mopro.swift would evaluate to false without this shim.
    .target(
      name: "COpenACFFI",
      path: "Sources/COpenACFFI",
      publicHeadersPath: "include"
    ),
    .binaryTarget(
      name: "OpenACSwiftBindings",
      url: "https://github.com/privacy-ethereum/zkID/releases/download/RSA-X.509-Cert-latest/MoproBindings.xcframework.zip",
      checksum: "f7f6c5c8f64154b2c098fd31e438eaefe0de7fbdaca23279bc67449ae4a59936"
    ),
    .testTarget(
      name: "OpenACSwiftTests",
      dependencies: [
        "OpenACSwift"
      ],
      resources: [
        .copy("TestVectors")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
