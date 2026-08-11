# Test Configuration

Integration tests load their environment setup from `config.json` in this folder.

The file format is:

```json
{
  "environments": [
    {
      "name": "smoke",
      "processTypes": ["onboarding"],
      "esUrl": "https://example.com/enrollment-server/",
      "esoUrl": "https://example.com/enrollment-server-onboarding/",
      "mobileConfig": "...",
      "otpMock": "AUTO",
      "servicesMock": true,
      "reKycProcessType": "re-kyc",
      "cloudServerUrl": "https://example.com/powerauth-cloud",
      "cloudServerLogin": "...",
      "cloudServerPassword": "...",
      "cloudApplicationId": "..."
    }
  ]
}
```

## Properties

- `environments`: List of test environments. Tests run for every environment in this array.
- `name`: Environment name used in test logs.
- `processTypes`: List of onboarding process types. Tests run once for each process type. These process types must exist and be configured on the server for the selected environment.
- `esUrl`: Base URL of the enrollment server used for `PowerAuthSDK` configuration.
- `esoUrl`: Base URL of the enrollment onboarding server used by `WDOActivationService`, `WDOVerificationService`, and `WDOConfigurationService`.
- `mobileConfig`: PowerAuth mobile configuration string for the given environment.
- `otpMock`: OTP detail endpoint strategy.
- `servicesMock`: Whether the environment supports mocked downstream services required by the full integration flow.
- `reKycProcessType`: Process type configured on the server with `existingActivation=true`, used by the Re-KYC integration tests. Defaults to `"re-kyc"` when not present.
- `cloudServerUrl` / `cloudServerLogin` / `cloudServerPassword` / `cloudApplicationId`: PowerAuth Cloud admin API connection, used to create an activation code directly (via `POST /v2/registrations`), bypassing the onboarding process. Required for the Re-KYC integration tests (`start re-verification`, `re-verification activation flags`); these tests are skipped when omitted.

## `otpMock` values

- `ESO`: Use the OTP detail endpoint on the enrollment onboarding server.
- `AUTO`: Automatically derive the mock OTP endpoint from the onboarding server URL.
- Full URL: Use the provided URL as a custom OTP detail endpoint.

## Notes

- CI provides this file through the `TESTS_CONFIG` secret.
- Keep real credentials and internal URLs out of commits unless they are meant to be public.
