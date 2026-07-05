// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Zephyr",
    platforms: [.iOS("17.0"), .tvOS("17.0"), .watchOS("10.0")],
    products: [.library(name: "Zephyr", targets: ["Zephyr"])],
    targets: [.target(name: "Zephyr", path: "Sources")],  
    swiftLanguageVersions: [.v5]
)
