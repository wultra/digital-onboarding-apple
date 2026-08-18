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
@testable import WultraDigitalOnboarding
internal import WultraPowerAuthNetworking

// MARK: - NOTE TO THE TESTS -
// These tests expect to run against enrollment-onboarding-server that is connected to
// mock providers for document scan and presence check.
// It is not sending real documents to the server, but rather JSON instructions for the mock server.
// (see getMockDocumentToUpload)

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
                throw SimpleError("[\(x.processType)] Expected to throw error but got \(result)")
            } catch let error as WPNError {
                guard error.reason == .wdo_activation_notRunning else {
                    throw SimpleError("[\(x.processType)] Invalid error type: \(error)")
                }
                print("[\(x.processType)] Expected error: \(error)")
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
                print("[\(x.processType)] Skipping test as OTP is not required")
                return
            }
            try await x.start()
            do {
                let otp = config.otpForIdentification ? nil : "123456"
                try await x.activate(otp: otp)
                throw SimpleError("[\(x.processType)] Activate should fail")
            } catch let error {
                // make sure that powerauth activation failed
                #expect(error.isPowerAuthError, "[\(x.processType)] Error throw during activation: \(error)")
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
                throw SimpleError("[\(x.processType)] Unexpected state: \(startResult.shadowState)")
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
                         throw SimpleError("[\(x.processType)] Processing did not finish after \(maxRetries) retries (\(Int(Double(maxRetries) * pollIntervalSeconds)) s)")
                     }
                     retryCount += 1
                     try await Task.sleep(for: .seconds(pollIntervalSeconds))
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
                throw SimpleError("[\(x.processType)] Unexpected state: \(newStatus.state.shadowState)")
            }
            
            // make sure all selected document are in the process
            for documentToScan in documentsToScan {
                #expect(newProcess.documents.contains { $0.type == documentToScan.patchedType })
            }
            
            // if services are not mocked on the server, we can't continue past document upload
            guard env.servicesMock else {
                print("[\(x.processType)] Skipping rest of onboarding flow — servicesMock is disabled for '\(env.name)'; services are not mocked and the server expects real documents.")
                return
            }

            // wait for document processing to finish
            var state = try await waitForNonProcessingStatus()

            // handle document re-scan if documents were rejected
            // (with mocked services this shouldn't happen, but handle it for robustness)
            if state.shadowState == .scanDocument {
                guard case .scanDocument = state else {
                    throw SimpleError("[\(x.processType)] Unexpected state: \(state.shadowState)")
                }
                for doc in documentsToScan {
                    _ = try await x.verification.documentsSubmit(files: try doc.uploadFiles())
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
                let newPa = try PowerAuthSDK(configuration: .init(
                    instanceId: UUID().uuidString,
                    baseEndpointUrl: env.esUrl,
                    configuration: env.mobileConfig
                ))
                let password = PowerAuthPassword(string: "1234")
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
                print("[\(x.processType)] Full onboarding flow completed successfully!")
            } else if state.shadowState == .failed {
                throw SimpleError("[\(x.processType)] Verification ended in failed state — mocked services should not fail")
            } else if state.shadowState == .endstate {
                throw SimpleError("[\(x.processType)] Verification ended in endstate — mocked services should not reach endstate")
            } else {
                throw SimpleError("[\(x.processType)] Unexpected final state: \(state.shadowState)")
            }
        }
    }
    
    @Test(arguments: ServerEnvironment.loaded)
    func `start re-verification after onboarding-based activation`(env: ServerEnvironment) async throws {
        try await env.test { x in
            guard let activePowerAuth = try await x.startAndActivateAndVerify() else {
                return
            }

            let preReKycStatus = try await activePowerAuth.fetchActivationStatus()
            #expect(preReKycStatus.needVerification == false)

            // Re-KYC operates on the now-active PowerAuth instance, which may differ from x.powerAuth
            // if activationFinish swapped to a new one.
            let reKycHelper = try TestHelper(environment: env, processType: x.processType, customPaInstance: activePowerAuth)

            let reVerificationResult = try await reKycHelper.verification.startReVerification(processType: env.reKycProcessType)
            #expect(reVerificationResult.state.shadowState == .intro)

            // startReVerification alone must not flip needVerification yet - only `identity/init`
            // (triggered by the subsequent `start(consentApprovedByUser:)` call) does that.
            let statusAfterReVerification = try await activePowerAuth.fetchActivationStatus()
            #expect(statusAfterReVerification.needVerification == false)

            let startResult = try await reKycHelper.verification.start(consentApprovedByUser: .notRequired)
            #expect(startResult.shadowState == .documentsToScanSelect)
            try await reKycHelper.assertVerificationState(.documentsToScanSelect)

            // The reliable check regardless of which flag name the backend uses.
            let status = try await activePowerAuth.fetchActivationStatus()
            #expect(status.needVerification)
            
            print("Re-KYC test succesfull")
        }
    }
    
    @Test(arguments: ServerEnvironment.loaded)
    func `start re-verification called twice in a row`(env: ServerEnvironment) async throws {
        try await env.test { x in
            guard let activePowerAuth = try await x.startAndActivateAndVerify() else {
                return
            }

            let reKycHelper = try TestHelper(environment: env, processType: x.processType, customPaInstance: activePowerAuth)

            let first = try await reKycHelper.verification.startReVerification(processType: env.reKycProcessType)
            #expect(first.state.shadowState == .intro, "[\(x.processType)] Expected intro state after first startReVerification, got: \(first.state.shadowState)")

            let second = try await reKycHelper.verification.startReVerification(processType: env.reKycProcessType)
            #expect(second.state.shadowState == .intro, "[\(x.processType)] Expected intro state after second startReVerification, got: \(second.state.shadowState)")
        }
    }

    @Test(arguments: ServerEnvironment.loaded)
    func `cancel verification`(env: ServerEnvironment) async throws {
        
        try await env.test { x in
            // start valid onboarding
            guard let (_, consentRequired) = try await x.startAndActivate() else {
                return
            }
            
            _ = try await x.verification.start(consentApprovedByUser: consentRequired ? .approved : .notRequired)
            
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
