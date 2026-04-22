# Changelog

## 3.0.0 (TBA)

- **⚠️ BREAKING**: `WDOVerificationState.otp` now carries only `remainingAttempts`.
- `WDOConfigurationResponse` now includes optional `otpResendPeriodSeconds` (`nil` on older backends that do not provide the field yet).

## 2.0.0 (April, 2026)

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

## 1.3.0 (October, 2024)

- PowerAuth "server stack" `1.9+` is now required
- `powerauth-mobile-sdk` v `1.9.x` is now required
- `networking-apple` v `1.5.x` is now required

## 1.2.0 (July, 2024)

-  `WDOLogger` now provides `delegate` property
-  `WDOLogger.VerboseLevel` 
    -  renamed `all` -> `debug` 
    -  added an `info` option.

## 1.1.1 (Feb 29, 2024)

-  `WDOActivationService` and `WDOVerificationService` initializers no longer throw exceptions.

## 1.1.0 (Feb 9, 2024)

- Added support for the PowerAuth SDK 1.8.0+

## 1.0.1 (Feb 9, 2024)

- Added documentation

## 1.0.0 (Jan 10, 2024)

Initial release.
