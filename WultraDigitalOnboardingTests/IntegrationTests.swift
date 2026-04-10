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

import UIKit
import Testing
import PowerAuth2
import PowerAuthCore
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
            
            // expect default language
            #expect(x.verification.acceptLanguage == "en")
            
            // test language change
            x.verification.acceptLanguage = "cs"
            #expect(x.verification.acceptLanguage == "cs")
            
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
            let selectResult = try await x.verification.documentsSetSelectedTypes(types: documentsToScan.map({ $0.patchedType }))
            #expect(selectResult.shadowState == .scanDocument)
            try await x.assertVerificationState(.scanDocument)
            
            guard case .scanDocument(let process) = selectResult.state else {
                throw SimpleError("Unexpected state: \(startResult.shadowState)")
            }
            
            // make sure all selected document are in the process
            for documentToScan in documentsToScan {
                #expect(process.documents.contains { $0.type == documentToScan.patchedType })
            }
            
             func waitForNonProcessingStatus() async throws -> WDOVerificationState {
                 // Polling configuration: max 10 retries × 3 s = 30 s before giving up
                 let pollIntervalSeconds: Double = 3
                 let maxRetries = 10
                 var retryCount = 0

                 var statusResult = try await x.verification.status()
                 while statusResult.state.shadowState == .processing {
                     guard retryCount < maxRetries else {
                         throw SimpleError("Processing did not finish after \(maxRetries) retries (\(Int(Double(maxRetries) * pollIntervalSeconds)) s)")
                     }
                     retryCount += 1
                     // handle onboarding approval when processing is waiting for manual approval
                     if case .processing(let item) = statusResult.state, item == .onboardingApproval {
                         if let userId = x.lastCredentials.map({ "mockuser_\($0.clientNumber)" }) {
                             print("Process is waiting for onboarding approval, approving...")
                             try await approveOnboarding(
                                env: env,
                                processId: statusResult.serverData.processId,
                                userId: userId
                            )
                         } else {
                             print("Process is waiting for onboarding approval but no env/userId provided — waiting...")
                         }
                     }
                     try await Task.sleep(for: .seconds(pollIntervalSeconds))
                     statusResult = try await x.verification.status()
                }
                return statusResult.state
            }
            
             func waitForNonProcessingStatus() async throws -> WDOVerificationState {
                 var statusResult = try await x.verification.status()
                 while statusResult.state.shadowState == .processing {
                     // handle onboarding approval when processing is waiting for manual approval
                     if case .processing(let item) = statusResult.state, item == .onboardingApproval {
                         if let userId = x.lastCredentials.map({ "mockuser_\($0.clientNumber)" }) {
                             print("Process is waiting for onboarding approval, approving...")
                             try await approveOnboarding(
                                env: env,
                                processId: statusResult.serverData.processId,
                                userId: userId
                            )
                         } else {
                             print("Process is waiting for onboarding approval but no env/userId provided — waiting...")
                         }
                     }
                     try await Task.sleep(for: .seconds(3))
                     statusResult = try await x.verification.status()
                }
                return statusResult.state
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
                #expect(newProcess.documents.contains { $0.type == documentToScan.patchedType })
            }
            
            // empty jpeg used for document uploads
            let dummyJpeg =
            Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCABkAGQDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD5/ooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooAKKKKACiiigAooooA//2Q==")!
            
            // if services are not mocked on the server, we can't continue past document upload
            guard env.servicesMock else {
                
                // -- end APP RESTART SIMULATION
                
                // now lets try to upload fake files to test reupload
                for documentToScan in documentsToScan {

                    var documentsToUpload = [WDODocumentFile(data: dummyJpeg, type: documentToScan.patchedType, side: .front, originalDocumentId: nil, dataSignature: nil)]
                    if documentToScan.sideCount == 2 {
                        documentsToUpload.append(WDODocumentFile(data: dummyJpeg, type: documentToScan.patchedType, side: .back, originalDocumentId: nil, dataSignature: nil))
                    }
                    // upload to server
                    _ = try await x.verification.documentsSubmit(files: documentsToUpload)
                    // wait for processing
                    _ = try await waitForNonProcessingStatus()
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
                
                print("Skipping rest of onboarding flow — servicesMock is disabled for '\(env.name)'")
                return
            }

            // wait for document processing to finish
            var state = try await waitForNonProcessingStatus()

            // handle document re-scan if documents were rejected
            // (with mocked services this shouldn't happen, but handle it for robustness)
            if state.shadowState == .scanDocument {
                guard case .scanDocument = state else {
                    throw SimpleError("Unexpected state: \(state.shadowState)")
                }
                for doc in documentsToScan {
                    var filesToUpload = [WDODocumentFile(data: dummyJpeg, type: doc.patchedType, side: .front, originalDocumentId: nil)]
                    if doc.sideCount == 2 {
                        filesToUpload.append(WDODocumentFile(data: dummyJpeg, type: doc.patchedType, side: .back, originalDocumentId: nil))
                    }
                    _ = try await x.verification.documentsSubmit(files: filesToUpload)
                    state = try await waitForNonProcessingStatus()
                }
            }

            // presence check
            if state.shadowState == .presenceCheck {
                // init the presence check (server-side)
                _ = try await x.verification.presenceCheckInit()
                // with mocked services, we don't need an actual 3rd party SDK — just submit
                _ = try await x.verification.presenceCheckSubmit()
                // wait for processing after presence check
                state = try await waitForNonProcessingStatus()
            }

            // OTP verification
            if state.shadowState == .otp {
                // retrieve OTP via demo/mock endpoint
                let otp = try await x.verification.getOTP(strategy: env.otpGetDetailStrategy)
                let otpResult = try await x.verification.verifyOTP(otp: otp)
                state = otpResult.state
                // wait for processing if needed
                if state.shadowState == .processing {
                    state = try await waitForNonProcessingStatus()
                }
            }

            // finish activation (optional step based on server config)
            if state.shadowState == .activationFinish {
                // create a new PowerAuth instance for the final activation
                let newPa = PowerAuthSDK(configuration: .init(
                    instanceId: UUID().uuidString,
                    baseEndpointUrl: env.esUrl,
                    configuration: env.mobileConfig
                ))!
                let password = PowerAuthCorePassword(string: "1234")
                let finishResult = try await x.verification.finishActivation(
                    newPowerAuthInstance: newPa,
                    newActivationName: UIDevice.current.name,
                    newPassword: password,
                    validatePassword: false,
                    userIdentification: nil
                )
                state = finishResult.state

                // the original PA should now be removed
                let origPaStatus = try await x.powerAuth.fetchActivationStatus()
                #expect(origPaStatus.state == .removed)

                // the new PA should be active without verification flags
                let newPaStatus = try await newPa.fetchActivationStatus()
                #expect(newPaStatus.state == .active)
                #expect(newPaStatus.needVerification == false)
            }

            // at this point we should be in success or endstate
            if state.shadowState == .success {
                print("Full onboarding flow completed successfully!")
            } else if state.shadowState == .failed {
                throw SimpleError("Verification ended in failed state — mocked services should not fail")
            } else if state.shadowState == .endstate {
                throw SimpleError("Verification ended in endstate — mocked services should not reach endstate")
            } else {
                throw SimpleError("Unexpected final state: \(state.shadowState)")
            }
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

    /// Calls private test API to approve the onboarding process (simulates backoffice approval).
    private func approveOnboarding(env: ServerEnvironment, processId: String, userId: String) async throws {

        guard let authorization = env.authorization else {
            throw SimpleError("Cannot approve onboarding — no authorization configured for environment '\(env.name)'")
        }

        let baseUrl = env.esoUrl.hasSuffix("/") ? String(env.esoUrl.dropLast()) : env.esoUrl

        // step 1: get verification ID for the process
        let verificationsUrl = URL(string: "\(baseUrl)/api/private/test/process/\(processId)/identityVerifications")!
        var getRequest = URLRequest(url: verificationsUrl)
        getRequest.httpMethod = "GET"
        getRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        getRequest.setValue("Basic \(authorization)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: getRequest)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SimpleError("Failed to get identity verifications for process \(processId)")
        }

        let verificationIds = try JSONDecoder().decode([String].self, from: data)
        guard let verificationId = verificationIds.first else {
            print("No verification ID found for process \(processId), skipping approval.")
            return
        }

        print("Found verification ID: \(verificationId) for process \(processId)")

        // step 2: approve the verification
        let approveUrl = URL(string: "\(baseUrl)/api/private/client/approve")!
        var postRequest = URLRequest(url: approveUrl)
        postRequest.httpMethod = "POST"
        postRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postRequest.setValue("Basic \(authorization)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "processId": processId,
            "identityVerificationId": verificationId,
            "userId": userId,
            "approvalResult": "OK",
            "approvalResultReason": ""
        ]
        postRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, approveResponse) = try await URLSession.shared.data(for: postRequest)
        guard let approveHttpResponse = approveResponse as? HTTPURLResponse, approveHttpResponse.statusCode == 200 else {
            throw SimpleError("Failed to approve onboarding for process \(processId), verification \(verificationId)")
        }

        print("Onboarding approved for process \(processId), verification \(verificationId)")
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
                
                if !selected.contains(where: { $0.patchedType == document.patchedType }) {
                    selected.append(document)
                }
            }
        }
        
        return selected
    }
}

extension WDOConfigurationDocument {
    // TODO: Remove me after 2026
    // There was a BUG on a server, where driving license was named incorectly
    // This fixes it in environments where it wasn't deployed yet.
    var patchedType: String {
        if type == "DRIVING_LICENCE" {
            return "DRIVING_LICENSE"
        }
        return type
    }
}
