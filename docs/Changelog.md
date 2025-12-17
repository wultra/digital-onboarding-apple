# Changelog

### TBA
- `SDKInitRequestAttributes` now contains `platform` property (mainly to support BlinkID SDK).
- `WDOConfigurationService` allows to fetch Wultra Digital Onboarding configuration from the server. 
- Added support for `processType` and `activationCode` in `WDOActivationService`

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
