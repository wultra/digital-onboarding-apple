//
// Copyright 2025 Wultra s.r.o.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions
// and limitations under the License.
//

/// Configuration request object
struct WDOConfigurationRequest: Codable {
    let processType: String
}

/// Configuration response objects
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
