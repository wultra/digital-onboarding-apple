//
// Copyright 2026 Wultra s.r.o.
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

import Testing
import Foundation
@testable import WultraDigitalOnboarding

// MARK: - Documents Status Model Tests

struct DocumentsStatusModelTests {

    @Test
    func `documents status stores overall status and document details`() {
        let document = WDODocument(
            filename: "id_front.jpg",
            id: "doc-1",
            type: "ID_CARD",
            side: .front,
            status: .accepted,
            errors: nil
        )

        let status = WDODocumentsStatus(status: .verificationPending, documents: [document])

        #expect(status.status == .verificationPending)
        #expect(status.documents.count == 1)
        #expect(status.documents[0].filename == "id_front.jpg")
        #expect(status.documents[0].id == "doc-1")
        #expect(status.documents[0].type == "ID_CARD")
        #expect(status.documents[0].side == .front)
        #expect(status.documents[0].status == .accepted)
        #expect(status.documents[0].errors == nil)
    }

    @Test
    func `document status raw values match server format`() {
        #expect(WDODocumentStatus.accepted.rawValue == "ACCEPTED")
        #expect(WDODocumentStatus.uploadInProgress.rawValue == "UPLOAD_IN_PROGRESS")
        #expect(WDODocumentStatus.inProgress.rawValue == "IN_PROGRESS")
        #expect(WDODocumentStatus.verificationPending.rawValue == "VERIFICATION_PENDING")
        #expect(WDODocumentStatus.verificationInProgress.rawValue == "VERIFICATION_IN_PROGRESS")
        #expect(WDODocumentStatus.rejected.rawValue == "REJECTED")
        #expect(WDODocumentStatus.failed.rawValue == "FAILED")
    }
}

// MARK: - Document Payload Builder Tests

struct DocumentPayloadBuilderTests {

    private let sampleData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // tiny "jpeg" header

    @Test
    func `build creates correct request structure`() {
        let file = WDODocumentFile(data: sampleData, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let request = DocumentPayloadBuilder.build(processId: "proc-123", files: [file])

        #expect(request.processId == "proc-123")
        #expect(request.resubmit == false)
        #expect(request.documents.count == 1)
        #expect(request.documents[0].type == "ID_CARD")
        #expect(request.documents[0].side == .front)
        #expect(request.documents[0].filename == "id_card_front.jpg")
        #expect(request.documents[0].originalDocumentId == nil)
    }

    @Test
    func `build sets resubmit when any file has originalDocumentId`() {
        let file1 = WDODocumentFile(data: sampleData, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let file2 = WDODocumentFile(data: sampleData, type: "ID_CARD", side: .back, originalDocumentId: "orig-1")
        let request = DocumentPayloadBuilder.build(processId: "p", files: [file1, file2])

        #expect(request.resubmit == true)
    }

    @Test
    func `build does not set resubmit when no originalDocumentId`() {
        let file1 = WDODocumentFile(data: sampleData, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let file2 = WDODocumentFile(data: sampleData, type: "ID_CARD", side: .back, originalDocumentId: nil)
        let request = DocumentPayloadBuilder.build(processId: "p", files: [file1, file2])

        #expect(request.resubmit == false)
    }

    @Test
    func `document data is base64 encoded in payload`() {
        let file = WDODocumentFile(data: sampleData, type: "PASSPORT", side: .front, originalDocumentId: nil)
        let request = DocumentPayloadBuilder.build(processId: "p", files: [file])

        #expect(request.documents[0].data == sampleData.base64EncodedString())
    }

    @Test
    func `filename follows type_side lowercase convention`() {
        let front = WDODocumentFile(data: sampleData, type: "DRIVING_LICENSE", side: .front, originalDocumentId: nil)
        let back = WDODocumentFile(data: sampleData, type: "DRIVING_LICENSE", side: .back, originalDocumentId: nil)

        let request = DocumentPayloadBuilder.build(processId: "p", files: [front, back])
        #expect(request.documents[0].filename == "driving_license_front.jpg")
        #expect(request.documents[1].filename == "driving_license_back.jpg")
    }
}

// MARK: - Document File Equality & Hashing Tests

struct DocumentFileEqualityTests {

    private let data1 = Data([0x01])
    private let data2 = Data([0x02])

    @Test
    func `documents with same type and side are equal regardless of data`() {
        let a = WDODocumentFile(data: data1, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let b = WDODocumentFile(data: data2, type: "ID_CARD", side: .front, originalDocumentId: "orig-1")
        #expect(a == b)
    }

    @Test
    func `documents with different sides are not equal`() {
        let a = WDODocumentFile(data: data1, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let b = WDODocumentFile(data: data1, type: "ID_CARD", side: .back, originalDocumentId: nil)
        #expect(a != b)
    }

    @Test
    func `documents with different types are not equal`() {
        let a = WDODocumentFile(data: data1, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let b = WDODocumentFile(data: data1, type: "PASSPORT", side: .front, originalDocumentId: nil)
        #expect(a != b)
    }

    @Test
    func `equal documents produce same hash`() {
        let a = WDODocumentFile(data: data1, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let b = WDODocumentFile(data: data2, type: "ID_CARD", side: .front, originalDocumentId: "x")
        #expect(a.hashValue == b.hashValue)
    }

    @Test
    func `set deduplicates documents by type and side`() {
        let a = WDODocumentFile(data: data1, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let b = WDODocumentFile(data: data2, type: "ID_CARD", side: .front, originalDocumentId: nil)
        let c = WDODocumentFile(data: data1, type: "ID_CARD", side: .back, originalDocumentId: nil)
        let set = Set([a, b, c])
        #expect(set.count == 2) // front + back
    }
}

// MARK: - Document Side Conversion Tests

struct DocumentSideConversionTests {

    @Test
    func `WDODocumentSide to API type round trips`() {
        #expect(WDODocumentSide.front.apiType == .front)
        #expect(WDODocumentSide.back.apiType == .back)
        #expect(WDODocumentSide.from(apiType: .front) == .front)
        #expect(WDODocumentSide.from(apiType: .back) == .back)
    }

    @Test
    func `DocumentSubmitFileSide raw values match server format`() {
        #expect(DocumentSubmitFileSide.front.rawValue == "FRONT")
        #expect(DocumentSubmitFileSide.back.rawValue == "BACK")
    }
}

// MARK: - Verification State Description Tests

struct VerificationStateDescriptionTests {

    @Test
    func `all states have non-empty descriptions`() {
        let states: [WDOVerificationState] = [
            .intro(consentRequired: true),
            .intro(consentRequired: false),
            .scanDocument(.init(status: .uploadInProgress, documents: [])),
            .processing(.other),
            .processing(.documentUpload),
            .processing(.documentVerification),
            .processing(.documentAccepted),
            .processing(.documentsCrossVerification),
            .processing(.verifyingPresence),
            .processing(.clientVerification),
            .processing(.clientAccepted),
            .processing(.onboardingApproval),
            .presenceCheck,
            .otp(remainingAttempts: 3, otpResendPeriodInSeconds: 60),
            .activationFinish,
            .failed,
            .endstate(.rejected, rejectReason: "fraud"),
            .endstate(.limitReached, rejectReason: nil),
            .endstate(.other, rejectReason: nil),
            .success
        ]

        for state in states {
            #expect(state.description.isEmpty == false, "Description should not be empty for \(state)")
            #expect(state.description.hasPrefix("WDOVerificationState"))
        }
    }

    @Test
    func `processing item descriptions are unique`() {
        let items: [WDOVerificationState.ProcessingItem] = [
            .other, .documentUpload, .documentVerification, .documentAccepted,
            .documentsCrossVerification, .verifyingPresence, .clientVerification,
            .clientAccepted, .onboardingApproval
        ]
        let descriptions = Set(items.map(\.description))
        #expect(descriptions.count == items.count, "Each processing item should have a unique description")
    }

    @Test
    func `endstate reason descriptions are unique`() {
        let reasons: [WDOVerificationState.EndstateReason] = [.rejected, .limitReached, .other]
        let descriptions = Set(reasons.map(\.description))
        #expect(descriptions.count == reasons.count)
    }
}

// MARK: - Processing Item Mapping Tests

struct ProcessingItemMappingTests {

    @Test
    func `all VerificationStatus reasons map to correct ProcessingItems`() {
        let mapping: [(VerificationStatus.Reason, WDOVerificationState.ProcessingItem)] = [
            (.unknown, .other),
            (.documentUpload, .documentUpload),
            (.documentVerification, .documentVerification),
            (.documentAccepted, .documentAccepted),
            (.documentsCrossVerification, .documentsCrossVerification),
            (.clientVerification, .clientVerification),
            (.clientAccepted, .clientAccepted),
            (.onboardingApproval, .onboardingApproval),
            (.verifyingPresence, .verifyingPresence)
        ]

        for (reason, expectedItem) in mapping {
            let result = WDOVerificationState.ProcessingItem.from(reason)
            #expect(result == expectedItem, "Reason \(reason) should map to \(expectedItem)")
        }
    }
}

// MARK: - VerificationStatus Translation Tests

struct VerificationStatusTranslationTests {

    private func makeResponse(
        phase: IdentityVerificationPhase?,
        status: IdentityVerificationStatus,
        consentRequired: Bool? = nil,
        rejectReason: String? = nil
    ) throws -> IdentityStatusResponse {
        var json: [String: Any] = [
            "processId": "test-proc",
            "processType": "onboarding",
            "identityVerificationStatus": status.rawValue,
            "config": ["otpResendPeriodSeconds": 30]
        ]
        if let phase { json["identityVerificationPhase"] = phase.rawValue }
        if let consentRequired { json["consentRequired"] = consentRequired }
        if let rejectReason { json["rejectReason"] = rejectReason }

        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(IdentityStatusResponse.self, from: data)
    }

    @Test
    func `notInitialized with no phase returns intro`() throws {
        let response = try makeResponse(phase: nil, status: .notInitialized, consentRequired: true)
        let result = try VerificationStatus.from(status: response)
        guard case .intro(let consentRequired) = result else {
            throw SimpleError("Expected intro, got \(result)")
        }
        #expect(consentRequired == true)
    }

    @Test
    func `notInitialized defaults to consent required`() throws {
        let response = try makeResponse(phase: nil, status: .notInitialized) // consentRequired nil
        let result = try VerificationStatus.from(status: response)
        guard case .intro(let consentRequired) = result else {
            throw SimpleError("Expected intro, got \(result)")
        }
        #expect(consentRequired == true) // default on native platforms
    }

    @Test
    func `documentUpload inProgress returns documentScan`() throws {
        let response = try makeResponse(phase: .documentUpload, status: .inProgress)
        let result = try VerificationStatus.from(status: response)
        guard case .documentScan = result else {
            throw SimpleError("Expected documentScan, got \(result)")
        }
    }

    @Test
    func `documentUpload verificationPending returns statusCheck documentVerification`() throws {
        let response = try makeResponse(phase: .documentUpload, status: .verificationPending)
        let result = try VerificationStatus.from(status: response)
        guard case .statusCheck(let reason) = result else {
            throw SimpleError("Expected statusCheck, got \(result)")
        }
        #expect(reason == .documentVerification)
    }

    @Test
    func `presenceCheck notInitialized returns presenceCheck`() throws {
        let response = try makeResponse(phase: .presenceCheck, status: .notInitialized)
        let result = try VerificationStatus.from(status: response)
        guard case .presenceCheck = result else {
            throw SimpleError("Expected presenceCheck, got \(result)")
        }
    }

    @Test
    func `otp verificationPending returns otp`() throws {
        let response = try makeResponse(phase: .otp, status: .verificationPending)
        let result = try VerificationStatus.from(status: response)
        guard case .otp = result else {
            throw SimpleError("Expected otp, got \(result)")
        }
    }

    @Test
    func `onboardingApproval inProgress returns statusCheck onboardingApproval`() throws {
        let response = try makeResponse(phase: .onboardingApproval, status: .inProgress)
        let result = try VerificationStatus.from(status: response)
        guard case .statusCheck(let reason) = result else {
            throw SimpleError("Expected statusCheck, got \(result)")
        }
        #expect(reason == .onboardingApproval)
    }

    @Test
    func `onboardingApproval rejected returns rejected`() throws {
        let response = try makeResponse(phase: .onboardingApproval, status: .rejected)
        let result = try VerificationStatus.from(status: response)
        guard case .rejected = result else {
            throw SimpleError("Expected rejected, got \(result)")
        }
    }

    @Test
    func `completed accepted returns success`() throws {
        let response = try makeResponse(phase: .completed, status: .accepted)
        let result = try VerificationStatus.from(status: response)
        guard case .success = result else {
            throw SimpleError("Expected success, got \(result)")
        }
    }

    @Test
    func `activationFinish returns activationFinish regardless of status`() throws {
        for status in [IdentityVerificationStatus.notInitialized, .inProgress, .accepted, .verificationPending] {
            let response = try makeResponse(phase: .activationFinish, status: status)
            let result = try VerificationStatus.from(status: response)
            guard case .activationFinish = result else {
                throw SimpleError("Expected activationFinish for status \(status), got \(result)")
            }
        }
    }

    @Test
    func `failed statuses return failed`() throws {
        let failedCases: [(IdentityVerificationPhase?, IdentityVerificationStatus)] = [
            (nil, .failed),
            (.documentUpload, .failed),
            (.documentVerification, .failed),
            (.documentVerificationFinal, .failed),
            (.clientEvaluation, .failed),
            (.presenceCheck, .failed),
            (.onboardingApproval, .failed),
            (.completed, .failed)
        ]
        for (phase, status) in failedCases {
            let response = try makeResponse(phase: phase, status: status)
            let result = try VerificationStatus.from(status: response)
            guard case .failed = result else {
                throw SimpleError("Expected failed for phase=\(String(describing: phase)), got \(result)")
            }
        }
    }

    @Test
    func `unknown phase-status combo throws`() throws {
        let response = try makeResponse(phase: .otp, status: .accepted)
        #expect(throws: (any Error).self) {
            _ = try VerificationStatus.from(status: response)
        }
    }
}

// MARK: - Document Action Mapping Tests

struct DocumentActionTests {

    @Test
    func `accepted status maps to proceed`() {
        let doc = Document(filename: "f.jpg", id: "1", type: "ID_CARD", side: .front, status: .accepted, errors: nil)
        #expect(doc.action == .proceed)
    }

    @Test
    func `rejected and failed status map to error`() {
        let rejected = Document(filename: "f.jpg", id: "1", type: "ID_CARD", side: .front, status: .rejected, errors: ["blur"])
        let failed = Document(filename: "f.jpg", id: "2", type: "ID_CARD", side: .front, status: .failed, errors: nil)
        #expect(rejected.action == .error)
        #expect(failed.action == .error)
    }

    @Test
    func `in-progress statuses map to wait`() {
        let waitStatuses: [DocumentStatus] = [.uploadInProgress, .inProgress, .verificationPending, .verificationInProgress]
        for status in waitStatuses {
            let doc = Document(filename: "f.jpg", id: "1", type: "ID_CARD", side: .front, status: status, errors: nil)
            #expect(doc.action == .wait, "Status \(status) should map to wait")
        }
    }
}

// MARK: - Result Extension Tests

struct ResultExtensionTests {

    @Test
    func `ok returns true for success`() {
        let result: Result<String, SimpleError> = .success("hello")
        #expect(result.ok == true)
        #expect(result.success == "hello")
        #expect(result.error == nil)
    }

    @Test
    func `ok returns false for failure`() {
        let result: Result<String, SimpleError> = .failure(SimpleError("fail"))
        #expect(result.ok == false)
        #expect(result.success == nil)
        #expect(result.error != nil)
    }

    @Test
    func `onSuccess callback fires only on success`() {
        var called = false
        let success: Result<Int, SimpleError> = .success(42)
        success.onSuccess { val in called = true; #expect(val == 42) }
        #expect(called)

        var calledOnError = false
        let failure: Result<Int, SimpleError> = .failure(SimpleError("x"))
        failure.onSuccess { _ in calledOnError = true }
        #expect(calledOnError == false)
    }

    @Test
    func `onError callback fires only on failure`() {
        var called = false
        let failure: Result<Int, SimpleError> = .failure(SimpleError("x"))
        failure.onError { _ in called = true }
        #expect(called)

        var calledOnSuccess = false
        let success: Result<Int, SimpleError> = .success(1)
        success.onError { _ in calledOnSuccess = true }
        #expect(calledOnSuccess == false)
    }

    @Test
    func `onSuccess and onError chain correctly`() {
        var successCalled = false
        var errorCalled = false

        let result: Result<String, SimpleError> = .success("ok")
        result
            .onSuccess { _ in successCalled = true }
            .onError { _ in errorCalled = true }

        #expect(successCalled)
        #expect(errorCalled == false)
    }
}

// MARK: - Codable Model Tests

struct CodableModelTests {

    @Test
    func `OnboardingStatus decodes all raw values`() throws {
        let cases: [(String, OnboardingStatus)] = [
            ("ACTIVATION_IN_PROGRESS", .activationInProgress),
            ("VERIFICATION_IN_PROGRESS", .verificationInProgress),
            ("FAILED", .failed),
            ("FINISHED", .finished)
        ]
        for (raw, expected) in cases {
            let data = try JSONEncoder().encode(raw)
            let decoded = try JSONDecoder().decode(OnboardingStatus.self, from: data)
            #expect(decoded == expected)
        }
    }

    @Test
    func `IdentityVerificationStatus decodes all raw values`() throws {
        let cases: [(String, IdentityVerificationStatus)] = [
            ("NOT_INITIALIZED", .notInitialized),
            ("VERIFICATION_PENDING", .verificationPending),
            ("IN_PROGRESS", .inProgress),
            ("ACCEPTED", .accepted),
            ("FAILED", .failed),
            ("REJECTED", .rejected)
        ]
        for (raw, expected) in cases {
            let data = try JSONEncoder().encode(raw)
            let decoded = try JSONDecoder().decode(IdentityVerificationStatus.self, from: data)
            #expect(decoded == expected)
        }
    }

    @Test
    func `IdentityVerificationPhase decodes all raw values`() throws {
        let cases: [(String, IdentityVerificationPhase)] = [
            ("DOCUMENT_UPLOAD", .documentUpload),
            ("PRESENCE_CHECK", .presenceCheck),
            ("CLIENT_EVALUATION", .clientEvaluation),
            ("DOCUMENT_VERIFICATION", .documentVerification),
            ("DOCUMENT_VERIFICATION_FINAL", .documentVerificationFinal),
            ("ONBOARDING_APPROVAL", .onboardingApproval),
            ("ACTIVATION_FINISH", .activationFinish),
            ("OTP_VERIFICATION", .otp),
            ("COMPLETED", .completed)
        ]
        for (raw, expected) in cases {
            let data = try JSONEncoder().encode(raw)
            let decoded = try JSONDecoder().decode(IdentityVerificationPhase.self, from: data)
            #expect(decoded == expected)
        }
    }

    @Test
    func `DocumentStatus decodes all raw values`() throws {
        let cases: [(String, DocumentStatus)] = [
            ("ACCEPTED", .accepted),
            ("UPLOAD_IN_PROGRESS", .uploadInProgress),
            ("IN_PROGRESS", .inProgress),
            ("VERIFICATION_PENDING", .verificationPending),
            ("VERIFICATION_IN_PROGRESS", .verificationInProgress),
            ("REJECTED", .rejected),
            ("FAILED", .failed)
        ]
        for (raw, expected) in cases {
            let data = try JSONEncoder().encode(raw)
            let decoded = try JSONDecoder().decode(DocumentStatus.self, from: data)
            #expect(decoded == expected)
        }
    }

    @Test
    func `ConsentResponse encodes and decodes`() throws {
        for value in [ConsentResponse.approved, .declined, .notRequired] {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(ConsentResponse.self, from: data)
            #expect(decoded == value)
        }
    }

    @Test
    func `WDOConfigurationResponse round trips through JSON`() throws {
        let json = """
        {
            "enabled": true,
            "otpForIdentification": false,
            "otpForIdentityVerification": true,
            "useTemporaryActivation": true,
            "documents": {
                "totalRequiredDocumentsCount": 2,
                "groups": [
                    {
                        "requiredDocumentsCount": 1,
                        "items": [
                            { "type": "ID_CARD", "sideCount": 2, "country": "CZE" },
                            { "type": "PASSPORT", "sideCount": 1, "country": null }
                        ]
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WDOConfigurationResponse.self, from: json)
        #expect(config.enabled == true)
        #expect(config.otpForIdentification == false)
        #expect(config.otpForIdentityVerification == true)
        #expect(config.useTemporaryActivation == true)
        #expect(config.documents.totalRequiredDocumentsCount == 2)
        #expect(config.documents.groups.count == 1)
        #expect(config.documents.groups[0].requiredDocumentsCount == 1)
        #expect(config.documents.groups[0].items.count == 2)
        #expect(config.documents.groups[0].items[0].type == "ID_CARD")
        #expect(config.documents.groups[0].items[0].sideCount == 2)
        #expect(config.documents.groups[0].items[0].country == "CZE")
        #expect(config.documents.groups[0].items[1].type == "PASSPORT")
        #expect(config.documents.groups[0].items[1].sideCount == 1)
        #expect(config.documents.groups[0].items[1].country == nil)

        // round trip
        let reencoded = try JSONEncoder().encode(config)
        let redecoded = try JSONDecoder().decode(WDOConfigurationResponse.self, from: reencoded)
        #expect(redecoded.documents.totalRequiredDocumentsCount == 2)
    }

    @Test
    func `IdentityStatusResponse decodes with custom coding keys`() throws {
        let json = """
        {
            "processId": "abc-123",
            "processType": "onboarding",
            "identityVerificationStatus": "IN_PROGRESS",
            "identityVerificationPhase": "DOCUMENT_UPLOAD",
            "consentRequired": false,
            "config": { "otpResendPeriodSeconds": 60 }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(IdentityStatusResponse.self, from: json)
        #expect(response.processId == "abc-123")
        #expect(response.processType == "onboarding")
        #expect(response.status == .inProgress)
        #expect(response.phase == .documentUpload)
        #expect(response.consentRequired == false)
        #expect(response.rejectReason == nil)
        #expect(response.config.otpResendPeriodSeconds == 60)
    }

    @Test
    func `DocumentSubmitRequest encodes to JSON`() throws {
        let request = DocumentSubmitRequest(
            processId: "p-1",
            resubmit: true,
            documents: [
                DocumentSubmitFile(filename: "id_card_front.jpg", type: "ID_CARD", side: .front, originalDocumentId: "orig-1", data: "base64data")
            ]
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["processId"] as? String == "p-1")
        #expect(dict["resubmit"] as? Bool == true)
        let docs = dict["documents"] as! [[String: Any]]
        #expect(docs.count == 1)
        #expect(docs[0]["filename"] as? String == "id_card_front.jpg")
        #expect(docs[0]["side"] as? String == "FRONT")
        #expect(docs[0]["originalDocumentId"] as? String == "orig-1")
    }

    @Test
    func `SDKInitResponseAttributes extracts first string property`() throws {
        let json = """
        { "attributes": { "someUnknownKey": "token-value-123" } }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SDKInitResponse.self, from: json)
        #expect(response.attributes.responseToken == "token-value-123")
    }

    @Test
    func `SDKInitResponseAttributes returns nil when no string properties`() throws {
        let json = """
        { "attributes": { "numericKey": 42 } }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SDKInitResponse.self, from: json)
        #expect(response.attributes.responseToken == nil)
    }

    @Test
    func `PresenceCheckInitResponse decodes session attributes`() throws {
        let json = """
        { "sessionAttributes": { "token": "abc", "nested": { "key": "val" }, "count": 5 } }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PresenceCheckInitResponse.self, from: json)
        #expect(response.attributes["token"] as? String == "abc")
        #expect((response.attributes["nested"] as? [String: Any])?["key"] as? String == "val")
        #expect(response.attributes["count"] as? Int == 5)
    }
}

// MARK: - Logger Tests

struct LoggerTests {

    @Test
    func `log level minimum verbose mapping`() {
        // Each log level has a required minimum verbose level
        // error < warning < info < debug
        WDOLogger.verboseLevel = .errors
        // We can't directly test private log method, but we can verify the enum relationships
        #expect(WDOLogger.VerboseLevel.off.rawValue == 0)
        #expect(WDOLogger.VerboseLevel.errors.rawValue == 1)
        #expect(WDOLogger.VerboseLevel.warnings.rawValue == 2)
        #expect(WDOLogger.VerboseLevel.info.rawValue == 3)
        #expect(WDOLogger.VerboseLevel.debug.rawValue == 4)
    }
}

// MARK: - WDODocumentFile Initializer Tests

struct DocumentFileInitTests {

    @Test
    func `convenience init with type and side`() {
        let data = Data([0x01, 0x02])
        let file = WDODocumentFile(data: data, type: "PASSPORT", side: .front, originalDocumentId: "orig-1", dataSignature: "sig")

        #expect(file.data == data)
        #expect(file.type == "PASSPORT")
        #expect(file.side == .front)
        #expect(file.originalDocumentId == "orig-1")
        #expect(file.dataSignature == "sig")
    }

    @Test
    func `convenience init allows nil originalDocumentId`() {
        let file = WDODocumentFile(data: Data([0xFF]), type: "ID_CARD", side: .back, originalDocumentId: nil)
        #expect(file.type == "ID_CARD")
        #expect(file.side == .back)
        #expect(file.originalDocumentId == nil)
    }
}

// MARK: - Configuration getDocumentsToScan Tests (from IntegrationTests extension)

struct ConfigurationDocumentSelectionTests {

    @Test
    func `selects required count from each group`() throws {
        let json = """
        {
            "enabled": true,
            "otpForIdentification": false,
            "otpForIdentityVerification": false,
            "useTemporaryActivation": false,
            "documents": {
                "totalRequiredDocumentsCount": 2,
                "groups": [
                    {
                        "requiredDocumentsCount": 1,
                        "items": [
                            { "type": "ID_CARD", "sideCount": 2, "country": "CZE" },
                            { "type": "PASSPORT", "sideCount": 1, "country": null }
                        ]
                    },
                    {
                        "requiredDocumentsCount": 1,
                        "items": [
                            { "type": "DRIVING_LICENSE", "sideCount": 2, "country": null }
                        ]
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WDOConfigurationResponse.self, from: json)
        let selected = config.getDocumentsToScan()

        #expect(selected.count == 2)
        // first from group 1 (ID_CARD), first from group 2 (DRIVING_LICENSE)
        #expect(selected[0].type == "ID_CARD")
        #expect(selected[1].type == "DRIVING_LICENSE")
    }

    @Test
    func `fills from remaining when groups dont cover total`() throws {
        let json = """
        {
            "enabled": true,
            "otpForIdentification": false,
            "otpForIdentityVerification": false,
            "useTemporaryActivation": false,
            "documents": {
                "totalRequiredDocumentsCount": 3,
                "groups": [
                    {
                        "requiredDocumentsCount": 1,
                        "items": [
                            { "type": "ID_CARD", "sideCount": 2, "country": null },
                            { "type": "PASSPORT", "sideCount": 1, "country": null }
                        ]
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(WDOConfigurationResponse.self, from: json)
        let selected = config.getDocumentsToScan()

        // 1 required from group = ID_CARD, then fill: PASSPORT (skip ID_CARD dup)
        // total still < 3 but no more unique docs available
        #expect(selected.count == 2)
        #expect(selected.contains { $0.type == "ID_CARD" })
        #expect(selected.contains { $0.type == "PASSPORT" })
    }
}
