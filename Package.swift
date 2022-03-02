// swift-tools-version:5.3.1

import PackageDescription

let package = Package(
    name: "YandexMusic",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_15), .iOS(.v10), .watchOS(.v3), .tvOS(.v10)],
    products: [
        .executable(name: "MusicYa", targets: ["MusicYa"]),
        .library(name: "MusicYaiOS", targets: ["MusicYaiOS"]),
        .library(name: "YandexMusic", targets: ["YandexMusic"]),
        .library(name: "YandexAuth", targets: ["YandexAuth"])
    ],
    dependencies: [
        .package(name: "console-kit", url: "https://github.com/vapor/console.git", from: "4.0.0"),
        .package(name: "swift-crypto", url: "https://github.com/apple/swift-crypto.git", from: "1.0.0"),
        .package(name: "XMLCoder", url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.13.1")
    ],
    targets: [
        .target(
            name: "MusicYa",
            dependencies: ["YandexMusic", "YandexAuth", .product(name: "ConsoleKit", package: "console-kit")],
            path: "./Sources/App"
        ),
        .target(
            name: "MusicYaiOS",
            dependencies: [
                "YandexMusic", "YandexAuth"
            ],
            path: "./Sources/iOS"
        ),
        .target(name: "YandexMusic", dependencies: [
            /// .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            .product(name: "XMLCoder", package: "XMLCoder")
        ]),
        .target(name: "YandexAuth", dependencies: []),
        .testTarget(name: "YandexMusicTests", dependencies: ["YandexMusic"])
    ]
)
