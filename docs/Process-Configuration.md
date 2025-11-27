# Process Configuration

With `WDOConfigurationService` you can retrieve the configuration of the onboarding process from the server. 
The configuration contains information about which steps are required to be performed during the onboarding process and which document types are supported or required for scanning.

## Retrieving the configuration

To retrieve the configuration, create an instance of `WDOConfigurationService` and call the `getConfiguration` method with the process type identifier.

Example:

```swift
let powerAuth = PowerAuthSDK(configuration: ....)
let configurationService = WDOConfigurationService(
    powerAuth: powerAuth,
    config: WPNConfig(baseUrl: "https://server.me/path")
)

let processType = "onboarding" // defined on your server
configurationService.getConfiguration(processType: processType) { result in
    switch result {
    case .success(let config):
        print("Configuration: \(config)")
    case .failure(let error):
        print("Failed to load configuration: \(error)")
    }
}
```

## Configuration response

```swift
/// Configuration response objects (as defined in the SDK)
public struct ConfigurationResponse: Codable {
    /// Is the onboarding process enabled
    let enabled: Bool
    /// Is OTP required for the first part - identification/activation.
    let otpForIdentification: Bool
    /// Is OTP required for the second part - identity verification.
    let optForIdentityVerification: Bool
    /// Documents required for identity verification.
    let documents: ConfigurationDocuments
}

struct ConfigurationDocument: Codable {
    /// Type of the document
    let type: String
    /// Is the document mandatory?
    let mandatory: Bool
    /// Number of sides the document has
    let sideCount: Int
}

struct ConfigurationDocuments: Codable {
    /// Number of required documents
    let requiredDocumentsCount: Int
    /// List of documents
    let items: [ConfigurationDocument]
}
```

## Read next
- [Device Activation](Device-Activation.md)
