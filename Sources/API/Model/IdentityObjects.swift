//
// Copyright 2023 Wultra s.r.o.
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

import Foundation
import WultraPowerAuthNetworking

struct IdentityInitRequest: Codable {
    /// ID of the process
    let processId: String
}

/// Response of the Identity Verification Status
struct IdentityStatusResponse: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case processId = "processId"
        case config = "config"
        case status = "identityVerificationStatus"
        case phase = "identityVerificationPhase"
        case consentRequired = "consentRequired"
    }
    
    let processId: String
    let status: IdentityVerificationStatus
    let phase: IdentityVerificationPhase?
    let config: IdentityConfig
    let consentRequired: Bool?
}

public typealias ISO8601Duration = String

struct IdentityConfig: Decodable {
    let otpResendPeriod: ISO8601Duration
}

/// Status of the current identity verification
enum IdentityVerificationStatus: String, Decodable {
    /// Identity verification is waiting for initialization
    case notInitialized = "NOT_INITIALIZED"
    /// All submitted documents are waiting for verification
    case verificationPending = "VERIFICATION_PENDING"
    /// Identity verification is in progress
    case inProgress = "IN_PROGRESS"
    /// Identity verification was successfully completed
    case accepted = "ACCEPTED"
    /// Identity verification has failed, an error occurred
    case failed = "FAILED"
    /// identity verification was rejected
    case rejected = "REJECTED"
}

/// Phase of the current identity verification
enum IdentityVerificationPhase: String, Decodable {
    /// Document upload is in progress
    case documentUpload = "DOCUMENT_UPLOAD"
    /// Presence check is in progress
    case presenceCheck = "PRESENCE_CHECK"
    /// Backend is verifying documents
    case clientEvaluation = "CLIENT_EVALUATION"
    /// Document verification is in progress
    case documentVerification = "DOCUMENT_VERIFICATION"
    /// Cross check on documents is in progress
    case documentVerificationFinal = "DOCUMENT_VERIFICATION_FINAL"
    /// Pending onboarding approval
    case onboardingApproval = "ONBOARDING_APPROVAL"
    /// Waiting for activation finish
    case activationFinish = "ACTIVATION_FINISH"
    /// OTP verification needed
    case otp = "OTP_VERIFICATION"
    /// Completed
    case completed = "COMPLETED"
}

/// Document submit request
struct DocumentSubmitRequest: Codable {
    /// ProcessID of the onboarding process
    let processId: String
    /// Is it resubmit?
    let resubmit: Bool
    /// Documents to submit
    let documents: [DocumentSubmitFile]
}

/// Data of document to submit.
struct DocumentSubmitFile: Codable {
    /// Name of the file
    let filename: String
    /// Type of the document
    let type: DocumentSubmitFileType
    /// Side of the document (for example front side of the ID card)
    let side: DocumentSubmitFileSide?
    /// Original document ID in case of re-upload
    let originalDocumentId: String?
    /// Data of the document
    let data: String
}

/// Types of available documents
enum DocumentSubmitFileType: String, Codable {
    /// National ID card
    case idCard = "ID_CARD"
    /// Passport
    case passport = "PASSPORT"
    /// Driving license
    case driversLicense = "DRIVING_LICENSE"
    /// Selfie photo
    case selfiePhoto = "SELFIE_PHOTO"
}

/// Side of the file
enum DocumentSubmitFileSide: String, Codable {
    /// Front side of an document. Usually the one with the picture
    case front = "FRONT"
    /// Back side of an document
    case back = "BACK"
}

/// Submitted document metadata
struct Document: Codable {
    /// Name of the file
    let filename: String
    /// Unique ID of the file
    let id: String
    /// Type of the file
    let type: DocumentSubmitFileType
    /// Side of the file
    let side: DocumentSubmitFileSide
    /// Status of the processing
    let status: DocumentStatus
    /// Possible errors
    let errors: [String]?
}

enum DocumentStatus: String, Codable {
    /// Document was accepted
    case accepted = "ACCEPTED"
    /// Document is being uploaded to the verification system by the backend
    case uploadInProgress = "UPLOAD_IN_PROGRESS"
    /// Document are being processed
    case inProgress = "IN_PROGRESS"
    /// Document is pending verification
    case verificationPending = "VERIFICATION_PENDING"
    /// Document is being verified
    case verificationInProgress = "VERIFICATION_IN_PROGRESS"
    /// Document was rejected
    case rejected = "REJECTED"
    /// Verification of the document failed
    case failed = "FAILED"
}

/// Status of the documents
struct DocumentStatusResponse: Codable {
    /// Overall status
    let status: DocumentStatus
    /// Status for each document.
    let documents: [Document]
}

/// Presence check init response
struct PresenceCheckInitResponse: Decodable {
    
    private enum Keys: String, CodingKey {
        case attributes = "sessionAttributes"
    }
    
    /// Dictionary of attributes needed for presence check initiation.
    let attributes: [String: Any]
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        attributes = try c.decode([String: Any].self, forKey: .attributes)
    }
}

/// Request with OTP verification
struct VerifyOTPRequest: Codable {
    /// ID of the process
    let processId: String
    /// OTP code
    let otpCode: String
}

/// Response of the OTP verify
struct VerifyOTPResponse: Codable {
    /// ID of the process
    let processId: String
    /// Current onboarding status
    let onboardingStatus: OnboardingStatus
    /// Was OTP verified?
    let verified: Bool
    /// Is OTP expired
    let expired: Bool
    /// How many attempts are remaining
    let remainingAttempts: Int
}

/// Request for activation finish
struct ActivationFinishRequest: Encodable {
    private enum Keys: String, CodingKey {
        case processId
        case userIdentification
    }
    /// ID of the process
    let processId: String
    /// Optional user identification data sent during activation finish.
    let userIdentification: Encodable?
    
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(processId, forKey: .processId)
        if let userIdentification {
            try c.encode(userIdentification, forKey: .userIdentification)
        }
    }
}

/// Activation finish response
struct ActivationFinishResponse: Codable {
    /// Activation code for the new instance
    let activationCode: String
}

struct SDKInitRequest: Codable {
    /// ID of the process
    let processId: String
    /// Attributes
    let attributes: SDKInitRequestAttributes
}

struct SDKInitRequestAttributes: Codable {
    
    private enum Keys: String, CodingKey {
        case challengeToken = "sdk-init-token"
        case platform = "platform"
        case origin = "origin"
    }
    
    /// Challenge value 'sdk-init-token'
    let challengeToken: String
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(challengeToken, forKey: .challengeToken)
        try c.encode("ios", forKey: .platform)
        try c.encodeIfPresent(Bundle.main.bundleIdentifier, forKey: .origin)
    }
}

struct SDKInitResponse: Codable {
    let attributes: SDKInitResponseAttributes
}

struct SDKInitResponseAttributes: Codable {

    let responseToken: String?
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: JSONCodingKeys.self)
        // This is pretty big oversimplification, but in general, we expect 1 string property with an unknown key (property name).
        // If this wont fit the customer needs, we gonna need to provide this API as generic or make it provider-based for
        // different SDK providers.
        responseToken = c.allKeys.compactMap { try? c.decode(String.self, forKey: $0) }.first
    }
}

struct ConsentTextRequest: Codable {
    let processId: String
    var consentType: String = "GDPR"
}

struct ConsentTextResponse: Codable {
    let consentText: String
}

struct ConsentApproveRequest: Codable {
    let processId: String
    let approved: Bool
    var consentType: String = "GDPR"
}
