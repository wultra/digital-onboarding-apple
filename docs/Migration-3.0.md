# Migration from 2.x to 3.0.x

This guide covers public API changes between `2.x` and `3.0.x`.

## Breaking Changes

1. Read OTP resend cooldown from configuration instead of verification status.

```swift
let configuration = try await configurationService.getConfiguration(processType: "onboarding")
let otpResendPeriodSeconds = configuration.otpResendPeriodSeconds
```

`otpResendPeriodSeconds` is optional and can be `nil` when you are still integrating with an older backend that does not return the field yet.

2. Update OTP state handling.

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

- Fetch and keep `WDOConfigurationResponse.otpResendPeriodSeconds` for the active process type, and handle `nil` for older backends.
- Update `switch` statements and pattern matching for `WDOVerificationState.otp`.
- Stop relying on OTP resend timing from `status()` results.
