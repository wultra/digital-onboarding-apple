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
import PowerAuth2
@testable import WultraDigitalOnboarding
internal import WultraPowerAuthNetworking

class IntegrationTests: BaseTestClass {
    
    override init() {
        super.init()
        super.enableAllDebugLogs()
    }
    
    @Test(arguments: ServerEnvironment.loaded)
    func `test config`(env: ServerEnvironment) async throws {
        
        try await env.test { x in
            let config = try await x.getConfig()
            #expect(config.documents.groups.count > 0)
        }
    }
    
    @Test(arguments: ServerEnvironment.loaded)
    func `test status before start`(env: ServerEnvironment) async throws {
        
        try await env.test { x in
            do {
                let result = try await x.activation.status()
                throw SimpleError("Expected to throw error but got \(result)")
            } catch let error as WPNError {
                guard error.reason == .wdo_activation_notRunning else {
                    throw SimpleError("Invalid error type: \(error)")
                }
                print("Expected error: \(error)")
            }
        }
    }
    
    @Test(arguments: ServerEnvironment.loaded)
    func `activation fail`(env: ServerEnvironment) async throws {
        try await env.test { x in
            let config = try await x.getConfig()
            guard config.otpForIdentification else {
                // There is a bug on the server, when OTP is not required, it ignores it
                // so it cannot be simulated
                // https://github.com/wultra/powerauth-server/issues/2249
                print("Skipping test as OTP is not required")
                return
            }
            try await x.start()
            do {
                let otp = config.otpForIdentification ? nil : "123456"
                try await x.activate(otp: otp)
                throw SimpleError("Activate should fail")
            } catch let error {
                // make sure that powerauth activation failed
                #expect(error.isPowerAuthError, "Error throw during activation: \(error)")
            }
        }
    }
    
    // we test as far as we can (until we hit server mocking limits)
    @Test(arguments: ServerEnvironment.loaded)
    func `full onboarding flow`(env: ServerEnvironment) async throws {
        
        try await env.test { x in
            
            // start valid onboarding
            guard let (config, consentRequired) = try await x.startAndActivate() else {
                return
            }
            
            // try to get consent when required
            if consentRequired {
                let consentContent = try await x.verification.getConsent()
                #expect(consentContent.isEmpty == false)
            }
            
            // if consent is required, first reject it
            if consentRequired {
                let startRejectResult = try await x.verification.start(consentApprovedByUser: .declined)
                #expect(startRejectResult.shadowState == .intro)
            }
            
            // start the verification
            let startResult = try await x.verification.start(consentApprovedByUser: consentRequired ? .approved : .notRequired)
            #expect(startResult.shadowState == .documentsToScanSelect) // returned state should be document to scan select
            try await x.assertVerificationState(.documentsToScanSelect) // now verify that it's the same on the server
            
            // select documents to scan
            let documentsToScan = config.getDocumentsToScan()
            let selectResult = try await x.verification.documentsSetSelectedTypes(types: documentsToScan.map({ $0.type }))
            #expect(selectResult.shadowState == .scanDocument)
            try await x.assertVerificationState(.scanDocument)
            
            guard case .scanDocument(let process) = selectResult.state else {
                throw SimpleError("Unexpected state: \(startResult.shadowState)")
            }
            
            // make sure all selected document are in the process
            for documentToScan in documentsToScan {
                #expect(process.documents.contains { $0.type == documentToScan.type })
            }
            
            // -- APP RESTART SIMULATION: now make sure that when the app is restarted, the process is the same...
            let recreatedVerificaiton = try TestHelper(environment: env, processType: x.processType, customPaInstance: x.powerAuth)
            // fetch status with a new verification service instance (but the same PA instance)
            let newStatus = try await recreatedVerificaiton.verification.status()
            
            // we should be in the scanDocument status (no document uploaded yet)
            guard case .scanDocument(let newProcess) = newStatus.state else {
                throw SimpleError("Unexpected state: \(startResult.shadowState)")
            }
            
            // make sure all selected document are in the process
            for documentToScan in documentsToScan {
                #expect(newProcess.documents.contains { $0.type == documentToScan.type })
            }
            // -- end APP RESTART SIMULATION
            
            // not lets try to upload fake files to test reupload
            for documentToScan in documentsToScan {
                
                if documentToScan.type == "DRIVING_LICENCE" {
                    // TODO: remove this once fixed on the backend
                    print("Skipping driving license because there is a bug on the backend (DRIVING_LICENSE is expected...)")
                    continue
                }
                
                // empty jpeg
                let dummyJpeg =
                Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCABkAGQDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD5/ooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooA//2Q==")!
                var documentsToUpload = [WDODocumentFile(data: dummyJpeg, type: documentToScan.type, side: .front, originalDocumentId: nil, dataSignature: nil)]
                if documentToScan.sideCount == 2 {
                    documentsToUpload.append(WDODocumentFile(data: dummyJpeg, type: documentToScan.type, side: .back, originalDocumentId: nil, dataSignature: nil))
                }
                // upload to server
                _ = try await x.verification.documentsSubmit(files: documentsToUpload)
                // wait for processing
                _ = try await waitForNonProcessingStatus(service: x.verification)
                // set testing callback to verify that all documents (in second try) have originalDocumentID
                // that were automatically added by the submit method...
                x.verification._testing_Callback = { _, data in
                    guard let files = data as? [WDODocumentFile] else {
                        D.fatalError("Unexpected type")
                    }
                    guard files.allSatisfy({ $0.originalDocumentId != nil }) else {
                        D.fatalError("All documents should have originalDocumentId")
                    }
                }
                // again
                _ = try await x.verification.documentsSubmit(files: documentsToUpload)
                x.verification._testing_Callback = nil
            }
            
            // this is where the test ends for now, because there is no mock service for documents or presence check
            // that would accept fake or invalid documents
        }
    }
    
    @Test(arguments: ServerEnvironment.loaded)
    func `cancel verification`(env: ServerEnvironment) async throws {
        
        try await env.test { x in
            // start valid onboarding
            guard try await x.startAndActivate() != nil else {
                return
            }
            
            _ = try await x.verification.start(consentApprovedByUser: .notRequired) // for simplicity not required
            
            // we should now be in document to scan select state
            try await x.assertVerificationState(.documentsToScanSelect)
            
            // restart and verify the state
            let restartResult = try await x.verification.restartVerification()
            #expect(restartResult.shadowState == .intro)
            
            // make sure that the server state matches
            try await x.assertVerificationState(.intro)
            
            // start again
            _ = try await x.verification.start(consentApprovedByUser: .notRequired)
            
            // We should now be in document to scan select state
            try await x.assertVerificationState(.documentsToScanSelect)
            
            // cancel whole process, after that, the onboarding should be finished
            try await x.verification.cancelWholeProcess()
            
            // after the process is canceled, the powerauth status should be removed
            let paStatus = try await x.powerAuth.fetchActivationStatus()
            #expect(paStatus.state == .removed)
        }
    }
    
    private func waitForNonProcessingStatus(service: WDOVerificationService) async throws -> WDOVerificationState {
        var state = (try await service.status()).state
        while state.shadowState == .processing {
            try await Task.sleep(for: .seconds(2))
            state = (try await service.status()).state
        }
        return state
    }
}

struct UnitTests {

    @Test
    func `scan process preserves server data through cache serialization`() throws {
        let process = WDOVerificationScanProcess(types: ["ID_CARD", "PASSPORT"])

        // Feed server data: ID_CARD with front (accepted) + back (rejected), PASSPORT with front (accepted)
        process.feed([
            Document(filename: "id_front.jpg", id: "srv-1", type: "ID_CARD", side: .front, status: .accepted, errors: nil),
            Document(filename: "id_back.jpg", id: "srv-2", type: "ID_CARD", side: .back, status: .rejected, errors: ["blur"]),
            Document(filename: "pp_front.jpg", id: "srv-3", type: "PASSPORT", side: .front, status: .accepted, errors: nil)
        ])

        // Serialize to v2 cache and deserialize
        let restored = try #require(WDOVerificationScanProcess(cacheData: try process.dataForCache()))

        // ID_CARD — two sides with correct server IDs and upload states
        let idCard = try #require(restored.documents.first { $0.type == "ID_CARD" })
        #expect(idCard.sides.count == 2)
        let idFront = try #require(idCard.sides.first { $0.type == .front })
        #expect(idFront.serverId == "srv-1")
        #expect(idFront.uploadState == .accepted)
        let idBack = try #require(idCard.sides.first { $0.type == .back })
        #expect(idBack.serverId == "srv-2")
        #expect(idBack.uploadState == .rejected)

        // PASSPORT — one side
        let passport = try #require(restored.documents.first { $0.type == "PASSPORT" })
        #expect(passport.sides.count == 1)
        let ppFront = try #require(passport.sides.first)
        #expect(ppFront.serverId == "srv-3")
        #expect(ppFront.uploadState == .accepted)
    }

    @Test
    func `v1 cache migrates to v2`() throws {
        let v1Cache = "v1:ID_CARD,PASSPORT"

        // v1 should parse correctly (no sides)
        let process = try #require(WDOVerificationScanProcess(cacheData: v1Cache))
        #expect(process.documents.count == 2)
        #expect(process.documents[0].type == "ID_CARD")
        #expect(process.documents[1].type == "PASSPORT")
        #expect(process.documents[0].sides.isEmpty)
        #expect(process.documents[1].sides.isEmpty)

        // re-encoding should produce v2 JSON
        let v2Cache = try process.dataForCache()
        #expect(v2Cache.contains("\"v\":2"))
        #expect(v2Cache.contains("ID_CARD"))
        #expect(v2Cache.contains("PASSPORT"))

        // v2 cache should round-trip correctly
        let restored = try #require(WDOVerificationScanProcess(cacheData: v2Cache))
        #expect(restored.documents.count == 2)
        #expect(restored.documents[0].type == "ID_CARD")
        #expect(restored.documents[1].type == "PASSPORT")
        #expect(restored.documents[0].sides.isEmpty)
        #expect(restored.documents[1].sides.isEmpty)
    }
}

extension WDOConfigurationResponse {
    
    // prepares documents to scan based on the requirements from the backend
    func getDocumentsToScan() -> [WDOConfigurationDocument] {
        
        // Take required documents from each group
        var selected = documents.groups.flatMap { group in
            group.items.prefix(group.requiredDocumentsCount)
        }
        
        // If still not enough, fill from remaining documents (without duplicates by type)
        if selected.count < documents.totalRequiredDocumentsCount {
            
            let allDocuments = documents.groups.flatMap(\.items)
            
            for document in allDocuments {
                guard selected.count < documents.totalRequiredDocumentsCount else {
                    break
                }
                
                if !selected.contains(where: { $0.type == document.type }) {
                    selected.append(document)
                }
            }
        }
        
        return selected
    }
}
