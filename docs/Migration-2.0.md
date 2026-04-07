# Migration from 1.3.x to 2.0.x

This guide covers public API changes between `1.3.x` and `2.0.x`.

This SDK now requires enrollment onboarding server `2.1.0+`.

## Breaking Changes

1. Rename initializer parameters:

```swift
let activation = WDOActivationService(powerAuth: powerAuth, networkingConfig: config)
let verification = WDOVerificationService(powerAuth: powerAuth, networkingConfig: config)
let configuration = WDOConfigurationService(powerAuth: powerAuth, networkingConfig: config)
```

2. `WDODocumentType` is now `String`.

```swift
let documentTypes: [WDODocumentType] = ["ID_CARD", "PASSPORT"]
```

Use values returned by `WDOConfigurationService.getConfiguration(processType:)`.

3. Update verification consent flow:

- `status()` now returns `StatusResult`. Read `result.state`.
- `consentGet()` was renamed to `getConsent()`.
- `consentApprove()` was replaced by `start(consentApprovedByUser:)`.
- `WDOVerificationState.intro` now carries `consentRequired`.

4. Update verification state handling:

- `WDOVerificationState.otp` now carries `otpResendPeriodInSeconds`.
- `WDOVerificationState.endstate` now carries optional `rejectReason`.
- Handle `activationFinish` by calling `finishActivation(...)`.

## Additions

- Added `WDOConfigurationService`.
- Added `processType` to activation start and verification status data.
- Added `async throws` variants for asynchronous APIs.
- Added `WDOBaseService` with shared `acceptLanguage` and `networking`.
- Demo `getOTP()` now accepts `strategy:`.

## Checklist

- Rename `config:` and `wpnConfig:` to `networkingConfig:`.
- Replace enum-style document types with backend string values.
- Read `StatusResult.state` instead of using the old `status()` return type directly.
- Replace `consentGet()` and `consentApprove()` calls.
- Handle `activationFinish`, `rejectReason`, and OTP resend period from returned states.