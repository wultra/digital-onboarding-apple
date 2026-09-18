// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "WultraDigitalOnboarding",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "WultraDigitalOnboarding", targets: ["WultraDigitalOnboarding"])
    ],
    traits: [
        .trait(
            name: "ENABLE_ONBOARDING_DEMO",
            description: "Exposes demo-only getOTP endpoints for Wultra demo/mock servers. Do not enable in production."
        )
    ],
    dependencies: [
        .package(url: "https://github.com/wultra/powerauth-mobile-sdk.git", .upToNextMinor(from: "2.0.0")),
        .package(url: "https://github.com/wultra/networking-apple.git", .upToNextMinor(from: "2.0.0"))
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
    swiftLanguageModes: [.v5]
)
