// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Zephyr",
    platforms: [.iOS(.v12), .tvOS(.v12), .watchOS(.v9), .visionOS(.v1)],
    products: [.library(name: "Zephyr", targets: ["Zephyr"])],
    targets: [.target(name: "Zephyr", path: "Sources")],  
    swiftLanguageVersions: [.v5]
)
