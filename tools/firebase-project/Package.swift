// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FirebaseProject", platforms: [.macOS(.v13)], dependencies: [
    .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.7")
], targets: [.executableTarget(name: "FirebaseProject", dependencies: ["XcodeProj"])])
