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
    public let enabled: Bool
    /// Is OTP required for the first part - identification/activation.
    public let otpForIdentification: Bool
    /// Is OTP required for the second part - identity verification.
    public let otpForIdentityVerification: Bool
    /// Documents required for identity verification.
    public let documents: ConfigurationDocuments
}

public struct ConfigurationDocument: Codable {
    /// Type of the document
    public let type: String
    /// Is the document mandatory?
    public let mandatory: Bool
    /// Number of sides the document has
    public let sideCount: Int
}

public struct ConfigurationDocuments: Codable {
    /// Number of required documents
    public let requiredDocumentsCount: Int
    /// List of documents
    public let items: [ConfigurationDocument]
}
```

## Read next
- [Device Activation](Device-Activation.md)
