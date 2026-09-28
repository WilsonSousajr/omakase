// swift-tools-version: 6.2
import PackageDescription

// OmakaseAPI depends on nothing: it is the bottom of Features -> Store -> API
// (spec, Structure). check-layers.sh fails if a dependency appears here.
let package = Package(
    name: "OmakaseAPI",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [.library(name: "OmakaseAPI", targets: ["OmakaseAPI"])],
    targets: [
        .target(name: "OmakaseAPI"),
        .testTarget(name: "OmakaseAPITests", dependencies: ["OmakaseAPI"]),
    ]
)
