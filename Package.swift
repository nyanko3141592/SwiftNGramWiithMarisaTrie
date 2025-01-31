// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
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
        .executable(
            name: "SwiftNGramExample",
            targets: ["Examples"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vovasty/SwiftyMarisa/", branch: "master")
    ],
    targets: [
        .target(
            name: "SwiftNGram",
            dependencies: ["SwiftyMarisa"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .target(
            name: "Examples",
            dependencies: ["SwiftNGram"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "SwiftNGramTests",
            dependencies: ["SwiftNGram"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ]
)
