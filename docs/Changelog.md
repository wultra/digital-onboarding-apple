# Changelog

## TBA

- This release requires Wultra Digital Onboarding server version 2.1 or higher.
- Document scan flow no longer proceeds to processing when additional documents are still selected locally.
- `SDKInitRequestAttributes` now contains `platform` and `origin` properties (mainly to support BlinkID SDK).
- `WDOConfigurationService` allows to fetch Wultra Digital Onboarding configuration from the server. 
- Added support for `processType` and `activationCode` in `WDOActivationService`
- Refactored document upload to use the new v2 API.
- `WDOVerificationService` now supports optional identity consent:
    - `WDOVerificationState.intro` now contains associated `consentRequired` property.
    - Removed `WDOVerificationState.consent` state.
    - `consentGet(completion:)` renamed to `getConsent(completion:)`.
    - `consentApprove(completion:)` replaced by `start(consentApprovedByUser:completion:)`.
- added `onboardingApproval` process type constant, which signals that the onboarding requires an approval step.
- new `activationFinish` state
  -  when this status is reached, the activation needs to be finalized by calling the `WDOVerificationService.finishActivation` method.
- removed `WDODocumentType` and `DocumentSubmitFileType` types and use `String` type instead to better accommodate dynamic configuration of document scan.
- added `async` variants for all asynchronous methods
- updated `WDOConfigurationObjects`, which now includes the `useTemporaryActivation` flag and the `country` of origin in the scanned document
- added optional `country` (ISO 3166-1 alpha-3) to `WDODocumentFile` for document submit and to document status response
- added `WDODocumentToScan` struct and new `documentsSetSelectedTypes(documents:)` method that accepts documents with optional country. The previous `documentsSetSelectedTypes(types:)` is now deprecated.
- `WDOScannedDocument` now carries optional `country` property
- added `processType` to IdentityStatusResponse to better distinguish between configured onboarding processes
- `WDOVerificationState.otp` now carries `otpResendPeriodInSeconds` as an associated value (previously available as `WDOVerificationService.otpResendPeriodInSeconds` property, which was removed)
- `WDOVerificationState.endstate` now carries optional `rejectReason` associated value with the server-provided rejection reason
- `WDOVerificationService.status` now returns `WDOVerificationService.StatusResult` which includes the verification state alongside `processId` and `processType` server data
- `WDOVerificationService.documentsSubmit` now automatically resolves `originalDocumentId` for files that don't provide it, based on previously cached process data (temporary workaround until solved on the backend)
- `WDOActivationService`, `WDOVerificationService`, and `WDOConfigurationService` now inherit from `WDOBaseService`, which consolidates shared functionality (`acceptLanguage`, `networking`).
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
