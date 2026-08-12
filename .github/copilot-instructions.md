# Copilot Instructions

## Build, test, and lint

| Task | Command | Notes |
| --- | --- | --- |
| Prepare local dependencies | `xcrun xcodebuild -project WultraDigitalOnboarding.xcodeproj -scheme WultraDigitalOnboarding -resolvePackageDependencies` | Useful for initial setup. The SDK and its dependencies (PowerAuth mobile SDK, WultraPowerAuthNetworking) are resolved through Swift Package Manager; Xcode also resolves them automatically. Carthage is no longer used. |
| Build the SDK | `sh scripts/build.sh` | Builds the `WultraDigitalOnboarding` scheme in Release for iPhone Simulator. |
| Run the full test suite | `./scripts/test.sh` | Runs the `WultraDigitalOnboardingTests` scheme on an auto-detected iOS simulator. |
| Run tests with environment config | `./scripts/test.sh -config "$CONFIG_JSON"` | Writes the JSON into `WultraDigitalOnboardingTests/config.json` before running the tests. Integration tests depend on that file. |
| Run a single test | `xcrun xcodebuild -project WultraDigitalOnboarding.xcodeproj -scheme WultraDigitalOnboardingTests -destination 'platform=iOS Simulator,name=<simulator>,OS=<ios-version>' -only-testing:WultraDigitalOnboardingTests/<SuiteName>/<TestName> test` | Use `xcrun xcodebuild -project WultraDigitalOnboarding.xcodeproj -scheme WultraDigitalOnboardingTests -showdestinations` to pick a valid simulator. Tests use Swift Testing suites from `WultraDigitalOnboardingTests/*.swift`, not XCTest case classes. |
| Run SwiftLint | `sh scripts/swiftlint.sh` | Downloads and uses a repo-local `./swiftlint` binary (v0.53.0) and matches CI's strict lint run. |
| Validate the podspec | `pod lib lint --allow-warnings` | Matches `.github/workflows/podlint.yml`. |

`scripts/xcodeselect.sh` pins the CI Xcode selection. If local CLI builds behave differently from CI, compare your active Xcode with that script.

## High-level architecture

- This repo ships a single `WultraDigitalOnboarding` library (`Package.swift`) and builds on top of `PowerAuth2`, `PowerAuthCore`, and `WultraPowerAuthNetworking`. Current package metadata targets Swift 5.9 and iOS 13.
- `Sources/API/Networking.swift` is the transport hub. It wraps one `WPNNetworkingService` and exposes three endpoint groups: `onboarding`, `identityVerification`, and `configuration`.
- `WDOBaseService` is the shared base for all public services. It owns the shared `Networking` object and exposes the common `acceptLanguage` and `networking` surface.
- `WDOActivationService` handles the pre-verification onboarding phase: start/status/cancel/activate/resendOTP. It persists `processId` and `activationCode` in Keychain under a key derived from the PowerAuth instance ID so activation can survive service recreation and app restarts.
- `WDOConfigurationService` fetches the server-driven process configuration: OTP requirements, resend cooldown, temporary activation usage, and the allowed document groups/types.
- `WDOVerificationService` handles the post-activation flow. Its `status()` call maps backend phase/status combinations to `WDOVerificationState`, and that state machine is the source of truth for which screen and API call comes next.
- Document selection/upload state lives in `WDOVerificationScanProcess` and `WDOScannedDocument`. `WDOVerificationService` caches that per `processId` in Keychain so rejected uploads can be resubmitted with the correct server document IDs.
- `PowerAuthExtensions.swift` adds onboarding-specific PowerAuth helpers such as `PowerAuthActivationStatus.needVerification` and activation helper wrappers.
- `finishActivation(...)` is the final handoff when the backend uses temporary activation. It creates activation on a brand-new `PowerAuthSDK` instance; the original instance becomes unusable after success.
- `WDOHostApp` is only a minimal host shell. The most representative integration behavior lives in `docs/*.md`, `WultraDigitalOnboardingTests/IntegrationTests.swift`, and `WultraDigitalOnboardingTests/HelperClasses.swift`.

## Key conventions

- Prefer the async APIs for new call sites. Public async methods mirror the callback APIs across activation, configuration, and verification.
- The verification flow is server-driven. Do not hardcode a client-side happy path; call `status()` and switch over `WDOVerificationState`.
- Get `processType`, document types, and OTP resend timing from `WDOConfigurationService`. Since 3.0, OTP resend cooldown comes from `WDOConfigurationResponse.otpResendPeriodSeconds`, not from `WDOVerificationState.otp`.
- Use backend-provided document `type` strings (for example `ID_CARD`, `PASSPORT`) from configuration results when calling `documentsSetSelectedTypes(types:)`.
- For document reuploads, preserve `originalDocumentId` by creating files from `WDOScannedDocument.createFileForUpload(...)` / `WDODocumentFile(scannedDocument:...)` when possible. `documentsSubmit` auto-fills missing original IDs from cached process data as a fallback, and that behavior is intentional.
- Activation and verification state are expected to survive service recreation through Keychain-backed caches. After app relaunch or new service creation, resync with `status()` instead of assuming in-memory state is authoritative.
- `finishActivation(...)` requires a fresh `PowerAuthSDK` instance that can start activation. After success, continue with the new instance, not the original one.
- Keep localization on the shared service surface via `acceptLanguage`; do not bolt on custom request header handling for these services.
- Verification errors are modeled as `WDOVerificationService.Fail`, which can carry a fallback `state`; activation/configuration errors are `WPNError`. Preserve that distinction instead of flattening everything into generic errors.
- Logging uses `WDOLogger` (`D`) for SDK logs and `WPNLogger` for HTTP traffic. Be careful with debug logging because it may include sensitive request data.
- Tests use the Swift Testing framework (`import Testing`, `@Test`, `#expect`), not XCTest. Integration tests iterate over every environment and `processType` loaded from `WultraDigitalOnboardingTests/config.json`, and the full onboarding flow assumes mocked downstream services.
- Respect `.swiftlint.yml` as-is. The repo intentionally disables several common SwiftLint rules and excludes generated/build directories.
- If a change affects public API or documented flow, keep `docs/SDK-Integration.md`, `docs/Process-Configuration.md`, `docs/Device-Activation.md`, `docs/Verifying-User.md`, `docs/Changelog.md`, and any relevant migration guide in sync.
