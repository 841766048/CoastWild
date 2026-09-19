// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoastWildCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "CoastWildCore", targets: ["CoastWildCore"])],
    targets: [
        .target(name: "CoastWildCore", path: "CoastWild/Core"),
        .testTarget(name: "CoastWildCoreTests", dependencies: ["CoastWildCore"], path: "Tests")
    ],
    swiftLanguageVersions: [.v5]
)
