// swift-tools-version: 6.2
import PackageDescription

// Features depends on Store only; it never calls the API (spec, Structure).
let package = Package(
    name: "OmakaseFeatures",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [.library(name: "OmakaseFeatures", targets: ["OmakaseFeatures"])],
    dependencies: [.package(path: "../OmakaseStore")],
    targets: [
        .target(name: "OmakaseFeatures", dependencies: ["OmakaseStore"]),
        .testTarget(name: "OmakaseFeaturesTests", dependencies: ["OmakaseFeatures", "OmakaseStore"]),
    ]
)
