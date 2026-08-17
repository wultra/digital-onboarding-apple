# Migration from 2.x to 3.0.x

This guide covers public API changes between `2.x` and `3.0.x`. This version also upgrades the SDK to the **PowerAuth mobile SDK `2.0.x`** (protocol 4.0) and **WultraPowerAuthNetworking `2.0.x`**.

## Dependency changes

- PowerAuth mobile SDK is now `2.0.x`.
- WultraPowerAuthNetworking is now `2.0.x`.

Update your app to PowerAuth mobile SDK `2.0.x` before adopting this version.

## Breaking Changes

1. `PowerAuthPassword` instead of `PowerAuthCorePassword`.

`WDOVerificationService.finishActivation(...)` now takes a `PowerAuthPassword` for its `newPassword` parameter. You no longer need to import `PowerAuthCore` at the call site.

Before:

```swift
import PowerAuthCore

let password = PowerAuthCorePassword(string: "1234")
verification.finishActivation(
    newPowerAuthInstance: newPaInstance,
    newActivationName: "my-new-activation-name",
    newPassword: password,
    validatePassword: true,
    userIdentification: nil
) { result in /* ... */ }
```

After:

```swift
let password = PowerAuthPassword(string: "1234")
verification.finishActivation(
    newPowerAuthInstance: newPaInstance,
    newActivationName: "my-new-activation-name",
    newPassword: password,
    validatePassword: true,
    userIdentification: nil
) { result in /* ... */ }
```

2. Read OTP resend cooldown from configuration instead of verification status.

```swift
let configuration = try await configurationService.getConfiguration(processType: "onboarding")
let otpResendPeriodSeconds = configuration.otpResendPeriodSeconds
```

`otpResendPeriodSeconds` is optional and can be `nil` when you are still integrating with an older backend that does not return the field yet.

3. Update OTP state handling.

Before:

```swift
case .otp(let remainingAttempts, let otpResendPeriodInSeconds):
    // use both values from verification status
```

After:

```swift
case .otp(let remainingAttempts):
    // read resend cooldown from configuration.otpResendPeriodSeconds
```

## Checklist

- Bump your app's PowerAuth mobile SDK to `2.0.x` and WultraPowerAuthNetworking to `2.0.x`.
- Replace `PowerAuthCorePassword` with `PowerAuthPassword` and remove now-unnecessary `import PowerAuthCore` statements.
- If you previously linked PowerAuth via Carthage for this SDK, switch to Swift Package Manager.
- Fetch and keep `WDOConfigurationResponse.otpResendPeriodSeconds` for the active process type, and handle `nil` for older backends.
- Update `switch` statements and pattern matching for `WDOVerificationState.otp`.
- Stop relying on OTP resend timing from `status()` results.
