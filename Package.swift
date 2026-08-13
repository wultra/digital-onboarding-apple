// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "WultraDigitalOnboarding",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "WultraDigitalOnboarding", targets: ["WultraDigitalOnboarding"])
    ],
    dependencies: [
        .package(url: "https://github.com/wultra/powerauth-mobile-sdk.git", from: "2.0.0"),
        .package(url: "https://github.com/wultra/networking-apple.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "WultraDigitalOnboarding",
            dependencies: [
                .product(name: "PowerAuth2", package: "powerauth-mobile-sdk"),
                .product(name: "WultraPowerAuthNetworking", package: "networking-apple")
            ],
            path: "Sources"
        )
    ],
    swiftLanguageVersions: [.v5]
)
