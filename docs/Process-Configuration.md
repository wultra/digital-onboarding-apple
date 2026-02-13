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
public struct WDOConfigurationResponse: Codable {
    /// Is the onboarding process enabled
    public let enabled: Bool
    /// Is OTP required for the first part - identification/activation.
    public let otpForIdentification: Bool
    /// Is OTP required for the second part - identity verification.
    public let otpForIdentityVerification: Bool
    /// Documents required for identity verification.
    public let documents: WDOConfigurationDocuments
}

/// Documents required for identity verification.
public struct WDOConfigurationDocuments: Codable {
    /// Number of total required documents
    public let totalRequiredDocumentsCount: Int
    /// Groups of documents
    public let groups: [WDOConfigurationDocumentGroup]
}

/// Group of documents in the configuration
public struct WDOConfigurationDocumentGroup: Codable {
    /// Number of required documents in the group
    public let requiredDocumentsCount: Int
    /// Documents in the group
    public let items: [WDOConfigurationDocument]
}

/// Configuration for a document
public struct WDOConfigurationDocument: Codable {
    /// Type of the document
    public let type: String
    /// Number of sides the document has
    public let sideCount: Int
}
```

## Read next
- [Device Activation](Device-Activation.md)
