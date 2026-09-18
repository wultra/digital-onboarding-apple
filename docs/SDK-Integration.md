# SDK Integration

## Requirements

- iOS 13.0+
- Xcode 16.3+ (Swift Package Manager integration uses [package traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md), which require the Swift 6.1 toolchain)
- [PowerAuth Mobile SDK](https://github.com/wultra/powerauth-mobile-sdk) needs to be available in your project
- [Enrollment Onboarding Server](https://developers.wultra.com/components/enrollment-server/develop/documentation/onboarding/index)

## Swift Package Manager

Add `https://github.com/wultra/digital-onboarding-apple` repository as a package in Xcode UI and add `WultraDigitalOnboarding` library as a dependency.

Alternatively, you can add the dependency manually. For example:

```swift
// swift-tools-version:6.1
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
        // Replace VERSION_DEFINITION with the actual package version.
        .package(url: "https://github.com/wultra/digital-onboarding-apple.git", from: "VERSION_DEFINITION")
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

## Demo endpoints (`getOTP`)

For testing against Wultra demo/mock servers, the SDK offers demo-only
`WDOActivationService.getOTP(...)` and `WDOVerificationService.getOTP(...)` methods that
retrieve the OTP directly, without waiting for an SMS or email. These are guarded by the
`ENABLE_ONBOARDING_DEMO` compilation flag and are **not** compiled in by default.

> ⚠️ Never enable this in a production application. The demo endpoints are only available on
> Wultra demo/mock deployments.

### Swift Package Manager

Unlike CocoaPods, SPM has no `post_install` hook to inject a compilation flag into a
dependency, and compilation conditions never propagate from your app to a package's target.
Instead, the flag is exposed as a **package trait** named `ENABLE_ONBOARDING_DEMO`. Enable it
on the dependency (this works in any build configuration, not just `debug`):

```swift
dependencies: [
    .package(
        url: "https://github.com/wultra/digital-onboarding-apple.git",
        from: "VERSION_DEFINITION",
        traits: [.defaults, "ENABLE_ONBOARDING_DEMO"]
    )
]
```

If you add the SDK through the Xcode UI, enable the `ENABLE_ONBOARDING_DEMO` trait in the
package dependency's trait selection (Xcode 16.3+).

### CocoaPods

Keep enabling the flag from your `Podfile` `post_install` hook, for example:

```rb
post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless target.name == 'WultraDigitalOnboarding'
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] ||= '$(inherited)'
      config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] << ' ENABLE_ONBOARDING_DEMO'
    end
  end
end
```

## Async/Await

All asynchronous public APIs also provide `async throws` variants.

```swift
let configuration = try await configurationService.getConfiguration(processType: "onboarding")
let status = try await verificationService.status()
```

## Read next

- [Process Configuration](Process-Configuration.md)
