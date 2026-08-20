# SDK Integration

## Requirements

- iOS 13.0+
- [PowerAuth Mobile SDK](https://github.com/wultra/powerauth-mobile-sdk) needs to be available in your project
- [Enrollment Onboarding Server](https://developers.wultra.com/components/enrollment-server/develop/documentation/onboarding/index)

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
        .package(url: "https://github.com/wultra/digital-onboarding-apple.git", .from("3.0.0"))
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

## Async/Await

All asynchronous public APIs also provide `async throws` variants.

```swift
let configuration = try await configurationService.getConfiguration(processType: "onboarding")
let status = try await verificationService.status()
```

## Read next

- [Process Configuration](Process-Configuration.md)
