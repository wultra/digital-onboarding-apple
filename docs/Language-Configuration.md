# Language Configuration

The language of content that might be localized can be configured via `acceptLanguage` property on any service that inherits from `WDOBaseService` (`WDOActivationService`, `WDOVerificationService`, and `WDOConfigurationService`).

The default language is `en`. Availability of languages depends on server configuration and implementation.

<!-- begin box info -->
The language properties are just a wrap-around of the underlying networking language configuration described in [our networking library documentation](https://github.com/wultra/networking-apple).
<!-- end -->

## Read next

- [Logging](Logging.md)