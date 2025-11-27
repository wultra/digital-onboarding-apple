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
struct ConfigurationRequest: Codable {
    let processType: String
}

/// Configuration response objects
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
