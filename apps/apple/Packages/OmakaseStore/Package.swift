// swift-tools-version: 6.2
import PackageDescription

// Store depends on API only (Features -> Store -> API; check-layers.sh).
let package = Package(
    name: "OmakaseStore",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [.library(name: "OmakaseStore", targets: ["OmakaseStore"])],
    dependencies: [.package(path: "../OmakaseAPI")],
    targets: [
        .target(name: "OmakaseStore", dependencies: ["OmakaseAPI"]),
        .testTarget(name: "OmakaseStoreTests", dependencies: ["OmakaseStore", "OmakaseAPI"]),
    ]
)
