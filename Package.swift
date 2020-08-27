// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "YandexMusic",
    platforms: [.macOS(.v10_15), .iOS(.v10), .watchOS(.v3), .tvOS(.v10)],
    products: [
        .executable(name: "MusicYa", targets: ["MusicYa"]),
        .library(name: "YandexMusic", targets: ["YandexMusic"]),
        .library(name: "YandexAuth", targets: ["YandexAuth"])
    ],
    dependencies: [
        .package(name: "console-kit", url: "https://github.com/vapor/console.git", from: "4.0.0"),
        .package(name: "swift-crypto", url: "https://github.com/apple/swift-crypto.git", from: "1.0.0"),
        .package(name: "XMLCoder", url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.11.1")
    ],
    targets: [
        .target(
            name: "MusicYa",
            dependencies: ["YandexMusic", "YandexAuth", .product(name: "ConsoleKit", package: "console-kit")],
            path: "./Sources/App"
        ),
        .target(name: "YandexMusic", dependencies: [
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "XMLCoder", package: "XMLCoder")
        ]),
        .target(name: "YandexAuth", dependencies: []),
        .testTarget(name: "YandexMusicTests", dependencies: ["YandexMusic"])
    ]
)
