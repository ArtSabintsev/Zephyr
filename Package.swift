// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "Zephyr",
    platforms: [.iOS(.v9), .tvOS(.v9)],
    products: [.library(name: "Zephyr", targets: ["Zephyr"])],
    targets: [.target(name: "Zephyr", path: "Sources")],  
    swiftLanguageVersions: [.v5]
)
