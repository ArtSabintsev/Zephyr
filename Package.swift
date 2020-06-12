// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "Zephyr",
    products: [.library(name: "Zephyr", targets: ["Zephyr"])],
    targets: [.target(name: "Zephyr", path: "Sources")],
    platforms: [.iOS(.v8)],  
    swiftLanguageVersions: [.v5]
)
