// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SwiftNGram",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SwiftNGram",
            targets: ["SwiftNGram"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vovasty/SwiftyMarisa/", branch: "master")
    ],
    targets: [
        .target(
            name: "SwiftNGram",
            dependencies: ["SwiftyMarisa"],
            cxxSettings: [
                .unsafeFlags(["-std=c++17", "-stdlib=libc++", "-enable-experimental-cxx-interop"])
            ]
        ),
        .testTarget(
            name: "SwiftNGramTests",
            dependencies: ["SwiftNGram"]
        ),
    ]
)
