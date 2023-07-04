// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Zephyr",
    platforms: [.iOS(.v11), .macOS(.v11), .tvOS(.v11), .watchOS("9.0")],
    products: [.library(name: "Zephyr", targets: ["Zephyr"])],
    targets: [.target(name: "Zephyr", path: "Sources")],  
    swiftLanguageVersions: [.v5]
)
