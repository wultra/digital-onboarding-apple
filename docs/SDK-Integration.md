# SDK Integration

## Requirements

- iOS 13.0+
- [PowerAuth Mobile SDK](https://github.com/wultra/powerauth-mobile-sdk) needs to be available in your project

## Swift Package Manager

Add `https://github.com/wultra/digital-onboarding-apple` repository as a package in Xcode UI and add `WultraDigitalOnboarding` library as a dependency.

Alternatively, you can add the dependency manually. For example:

```swift
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "YourLibrary",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "YourLibrary",
            targets: ["YourLibrary"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/wultra/digital-onboarding-apple.git", .from("1.3.0"))
    ],
    targets: [
        .target(
            name: "YourLibrary",
            dependencies: ["WultraDigitalOnboarding"]
        )
    ]
)
```

## Cocoapods

Add the following dependencies to your Podfile:

```rb
pod 'WultraDigitalOnboarding'
```

## Guaranteed PowerAuth Compatibility

| WDO SDK | PowerAuth SDK |  
|---------|---------      |
| `1.3.x` | `1.9.x`       |
| `1.1.x` - `1.2.x` | `1.8.x`       |
| `1.0.x` | `1.7.x`       |

## Xcode Compatibility

We recommend using Xcode version 15.0 or newer.

## Read next

- [Process Configuration](Process-Configuration.md)
