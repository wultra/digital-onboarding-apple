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
