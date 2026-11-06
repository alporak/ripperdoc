// swift-tools-version:5.10
// Ripperdoc.app: a SwiftUI front end for the ripperdoc CLI, which it carries in its bundle. Open this folder in Xcode, or
// build the .app with ./build-app.sh.
import PackageDescription

let package = Package(
    name: "Ripperdoc",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Ripperdoc", path: "Sources/Ripperdoc")
    ]
)
