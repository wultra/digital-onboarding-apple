# Changelog

## TBA

- Raised the Swift Package Manager tools version to `6.1` (requires Xcode 16.3+).
- The demo-only `getOTP()` endpoints are now exposed to SPM consumers through the `ENABLE_ONBOARDING_DEMO` package trait. Enable it on the package dependency to compile the demo endpoints in (off by default). See [SDK Integration](SDK-Integration.md#demo-endpoints-getotp).

## 3.1.0

- Added `WDOVerificationService.startReVerification` to support Re-KYC (repeated identity verification) for an already active PowerAuth instance, without creating a new activation. Requires PA Enrollment Onboarding Server `2.2.3` or newer.
- `ProcessResponse` now contains an optional `activationType` property indicating whether a new activation was created or an existing one was reused.

## 3.0.0

- **⚠️ BREAKING**: Upgraded to **PowerAuth mobile SDK `2.0.x`** (protocol 4.0) and **WultraPowerAuthNetworking `2.0.x`**.
- **⚠️ BREAKING**: `WDOVerificationService.finishActivation(...)` `newPassword` now takes `PowerAuthPassword` instead of `PowerAuthCorePassword`. The `PowerAuthCore` module no longer needs to be imported at the call site.
- **⚠️ BREAKING**: `WDOVerificationState.otp` now carries only `remainingAttempts`.
- `WDOConfigurationResponse` now includes optional `otpResendPeriodSeconds` (`nil` on older backends that do not provide the field yet).

## 2.0.0

- This release requires enrollment onboarding server version 2.1.0 or higher.
- Added `WDOConfigurationService` and configuration response models.
- Document scan flow no longer proceeds to processing when additional documents are still selected locally.
- `SDKInitRequestAttributes` now contains `platform` and `origin` properties (mainly to support BlinkID SDK).
- Added support for `processType` and `activationCode` in `WDOActivationService`
- `WDOActivationService.activate(otp:)` now accepts optional OTP.
- Refactored document upload to use the new v2 API.
- `WDOVerificationService` now supports optional identity consent:
    - `WDOVerificationState.intro` now contains associated `consentRequired` property.
    - Removed `WDOVerificationState.consent` state.
    - `consentGet(completion:)` renamed to `getConsent(completion:)`.
    - `consentApprove(completion:)` replaced by `start(consentApprovedByUser:completion:)`.
- Added `WDOVerificationState.ProcessingItem.onboardingApproval`.
- Added `activationFinish` state and `WDOVerificationService.finishActivation(...)`.
- `WDODocumentType` now uses `String` values.
- Added `async` variants for all asynchronous methods.
- `WDOConfigurationResponse` now includes `useTemporaryActivation` and document `country`.
- Added `processType` to verification status data.
- `WDOVerificationState.otp` now carries `otpResendPeriodInSeconds` as an associated value (previously available as `WDOVerificationService.otpResendPeriodInSeconds` property, which was removed)
- `WDOVerificationState.endstate` now carries optional `rejectReason`.
- `WDOVerificationService.status` now returns `WDOVerificationService.StatusResult` with `processId` and `processType`.
- `WDOVerificationService.documentsSubmit` now automatically resolves missing `originalDocumentId` from cached process data when possible.
- `WDOActivationService`, `WDOVerificationService`, and `WDOConfigurationService` now inherit from `WDOBaseService`, which provides shared `acceptLanguage` and `networking`.
- Demo `getOTP()` now accepts `strategy:` and uses `WDOGetOTPEndpointStrategy`.
- **Breaking:** Init parameter `config:` (on `WDOActivationService` and `WDOConfigurationService`) and `wpnConfig:` (on `WDOVerificationService`) renamed to `networkingConfig:` for consistency.

## 1.3.0

- PowerAuth "server stack" `1.9+` is now required
- `powerauth-mobile-sdk` v `1.9.x` is now required
- `networking-apple` v `1.5.x` is now required

## 1.2.0

-  `WDOLogger` now provides `delegate` property
-  `WDOLogger.VerboseLevel` 
    -  renamed `all` -> `debug` 
    -  added an `info` option.

## 1.1.1

-  `WDOActivationService` and `WDOVerificationService` initializers no longer throw exceptions.

## 1.1.0

- Added support for the PowerAuth SDK 1.8.0+

## 1.0.1

- Added documentation

## 1.0.0

Initial release.
