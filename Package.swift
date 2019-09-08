// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Zephyr",
    products: [.library(name: "Zephyr", targets: ["Zephyr"])],
    targets: [.target(name: "Zephyr", path: "Sources")]
)
