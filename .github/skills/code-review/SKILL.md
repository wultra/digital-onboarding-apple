---
name: code-review
description: Review pull requests in the Digital Onboarding SDK for Apple platforms. Use when reviewing Swift APIs, onboarding state, identity verification, security, or documentation changes.
---

# Digital Onboarding Apple SDK review

## Review contract

Verify the PR base, head, and current checkout. Normal changes target
`develop`; release branches are `release/a.b.x`. Approve by default. Report
only a proven PR-introduced issue with file/line, concrete impact, and an
actionable correction. Do not comment on style, formatting, CI/workflows,
possibilities, or missing optional tests. Do not post to GitHub without the
user's approval; every postable draft starts with `🤖`. Review grammar only in
public docs/Swift documentation when the base is not a release branch.

For non-release work, `WultraDigitalOnboarding.podspec` must declare
`0.0.1-dev`; release-to-`develop` changes must restore that version everywhere
one is declared. Release preparation is `scripts/prepare-release.sh`; its
required public material is `docs/Changelog.md` plus relevant migration/API
docs.

## Architecture and public surface

This is one Swift 5.9/iOS 13 library target, `WultraDigitalOnboarding`, from
`Sources/`, distributed through `Package.swift` and
`WultraDigitalOnboarding.podspec`. Its dependencies are `PowerAuth2` and
`WultraPowerAuthNetworking`.

* `Sources/Onboarding/WDOActivationService.swift` owns start/status/cancel,
  activation, and OTP resend flow.
* `Sources/Configuration/WDOConfigurationService.swift` and
  `WDOConfigurationObjects.swift` fetch server-driven process, document, and
  OTP configuration.
* `Sources/Verification/WDOVerificationService.swift`,
  `WDOVerificationState.swift`, `WDOVerificationScanProcess.swift`, and
  `WDODocumentFile.swift` drive post-activation verification/document uploads.
* `Sources/API/Networking.swift` is the common transport hub; `WDOBaseService`
  provides shared networking and `acceptLanguage`.
* `Sources/PowerAuthExtensions.swift`, `WDOError.swift`, and `WDOLogger.swift`
  are public compatibility/security surfaces; Keychain persistence is in
  `Sources/Other/KeychainWrapper.swift`.

Public integration documentation is `docs/SDK-Integration.md`,
`Device-Activation.md`, `Process-Configuration.md`, `Verifying-User.md`,
`Error-Handling.md`, `Language-Configuration.md`, `Logging.md`, migration
guides, and `docs/Changelog.md`. Tests are Swift Testing suites in
`WultraDigitalOnboardingTests/`.

## Flow, callback, and data invariants

The verification workflow is server-driven. `status()` and
`WDOVerificationState` determine the next screen/API call: do not replace that
state mapping with a client-side happy path. Use configuration-provided
document type strings and `otpResendPeriodSeconds`; do not revive obsolete
state-derived OTP timing. Preserve `Fail.state` for verification failures and
the distinct `WPNError` behavior for activation/configuration.

New public async methods must mirror the established callback API in result,
error, availability, and exactly-once completion. Review callback/async
bridges for continuation leaks, double callbacks, weak-delegate loss, and
callbacks after service teardown. `acceptLanguage` is the shared localization
surface, not an ad hoc header mutation.

Activation process ID/code and verification scan state persist by PowerAuth
instance/process ID in Keychain. Flag changes that lose this state across
service recreation, use the wrong cache key, or retain/upload a stale
server-side document ID. Reuploads must preserve `originalDocumentId` through
`WDOScannedDocument.createFileForUpload(...)`/`WDODocumentFile`; the fallback
cache fill in `documentsSubmit` is intentional. `finishActivation(...)`
requires a fresh usable `PowerAuthSDK`; success invalidates the original SDK.

## Security and focused review

Inspect `Networking.swift`, API models, PowerAuth extensions, Keychain, and
document file serialization for request signing/E2EE scope preservation,
untrusted response validation, optional/null decoding, and no exposure of
activation codes, credentials, tokens, keys, document images, IDs, or
personally identifiable data in `WDOLogger`/HTTP logs/errors. Do not weaken
secure persistence or turn transport/authentication failures into success.

For changed mappings, uploads, activation persistence, or public service
behavior, look for focused updates to `UnitTests.swift` or
`IntegrationTests.swift` where an existing seam covers it. Relevant validation
is `./scripts/test.sh`, `sh scripts/build.sh`, and `sh scripts/swiftlint.sh`;
do not make CI-only comments.
