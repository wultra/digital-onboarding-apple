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

class TestHelper {
    
    let powerAuth: PowerAuthSDK
    let activation: WDOActivationService
    let verification: WDOVerificationService
    let configuration: WDOConfigurationService
    let processType: String
    
    private let environment: ServerEnvironment
    
    init(environment: ServerEnvironment, processType: String, customPaInstance: PowerAuthSDK? = nil) throws {
        guard let pa = customPaInstance ?? PowerAuthSDK(
            configuration: .init(
                instanceId: UUID().uuidString,
                baseEndpointUrl: environment.esUrl,
                configuration: environment.mobileConfig
            )
        ) else {
            throw SimpleError("Failed to create PowerAuthSDK")
        }
        
        self.powerAuth = pa
        let url = URL(string: environment.esoUrl)!
        self.activation = WDOActivationService(powerAuth: powerAuth, config: .init(baseUrl: url))
        self.verification = WDOVerificationService(powerAuth: powerAuth, wpnConfig: .init(baseUrl: url))
        self.configuration = WDOConfigurationService(powerAuth: powerAuth, config: .init(baseUrl: url))
        self.environment = environment
        self.processType = processType
    }
    
    func getConfig() async throws -> WDOConfigurationResponse {
        let config = try await configuration.getConfiguration(processType: processType)
        print("Config for processType: \(processType) retrieved: \(config)")
        return config
    }
    
    func start(credentials: SampleCredentials = .demo()) async throws {
        try await activation.start(credentials: credentials, processType: processType)
        #expect(activation.hasActiveProcess)
        let status = try await activation.status()
        #expect(status == .activationInProgress)
    }
    
    func activate(otp: String?) async throws {
        // verify status
        let status = try await activation.status()
        #expect(status == .activationInProgress)
        
        // activate
        let result = try await activation.activate(otp: otp, activationName: UIDevice.current.name)
        print("activated: \(result.activationFingerprint)")
        
        // perist with random password
        try powerAuth.persist()
        
        // verify powerauth status
        let paStatus = try await powerAuth.fetchActivationStatus()
        #expect(paStatus.needVerification)
        #expect(paStatus.state == .active)
    }
    
    func startAndActivate(credentials: SampleCredentials = .demo()) async throws -> (config: WDOConfigurationResponse, consentRequired: Bool)? {
        
        let config = try await getConfig()
        try await start(credentials: credentials)
        
        if config.otpForIdentification && environment.getOTPsupported == false {
            print("Cannot test OTP flow as OTP retrieval it is not supported by the backend")
            return nil
        }
        
        // get otp when required
        let otp = config.otpForIdentification ? try await activation.getOTP() : nil
        try await activate(otp: otp)
        
        let consent: Bool
        if case .intro(let consentRequired) = try await verification.status().state {
            consent = consentRequired
        } else {
            throw SimpleError("Unexpected status")
        }
        
        return (config, consent)
    }
    
    func assertVerificationState(_ expectedState: VerificationStateShadow) async throws {
        let status = try await verification.status()
        #expect(status.state.shadowState == expectedState)
    }
}

extension ServerEnvironment {
    func test(customPaInstance: PowerAuthSDK? = nil, completion: (TestHelper) async throws -> Void) async throws {
        for processType in processTypes {
            print("Running test with process type '\(processType)' on the environment '\(name)'.")
            try await completion(try TestHelper(environment: self, processType: processType, customPaInstance: customPaInstance))
        }
    }
}

class BaseTestClass: PowerAuthLogDelegate {
    
    func enableAllDebugLogs() {
        WPNLogger.verboseLevel = .debug
        WPNLogger.logHttpTraffic = true
        WDOLogger.verboseLevel = .debug
        PowerAuthLogSetVerbose(true)
        PowerAuthLogSetEnabled(true)
        PowerAuthLogSetDelegate(self)
    }
    
    func powerAuthLog(_ log: String) {
        print(log)
    }
}

struct SampleCredentials: Codable {
    let clientNumber: String
    let birthDate: String
    
    static func demo() -> SampleCredentials {
        return .init(clientNumber: UUID().uuidString, birthDate: "1989/11/17")
    }
}

struct SimpleError: Error {
    
    private(set) var localizedDescription = ""
    
    init(_ message: String) {
        self.localizedDescription = message
    }
}

extension PowerAuthSDK {
    func fetchActivationStatus() async throws -> PowerAuthActivationStatus {
        try await withCheckedThrowingContinuation { cont in
            fetchActivationStatus { status, error in
                if let status {
                    cont.resume(returning: status)
                } else if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(throwing: SimpleError("No status or error returned"))
                }
            }
        }
    }
    
    func persist(password: String = UUID().uuidString) throws {
        return try persistActivation(withPassword: password)
    }
}

extension Error {
    var isPowerAuthError: Bool {
        (self as NSError).userInfo[PowerAuthErrorDomain] != nil ||
        (self as? WPNError)?.powerAuthErrorCode != nil
    }
}

struct ServerEnvironment: Decodable {
    let name: String
    let processTypes: [String]
    let esUrl: String
    let esoUrl: String
    let mobileConfig: String
    let getOTPsupported: Bool
    
    init(name: String, processTypes: [String], esUrl: String, esoUrl: String, config: String, getOTPsupported: Bool) {
        self.name = name
        self.processTypes = processTypes
        self.esUrl = esUrl
        self.esoUrl = esoUrl
        self.mobileConfig = config
        self.getOTPsupported = getOTPsupported
    }
}

struct ServerEnvironmentData: Decodable {
    let environments: [ServerEnvironment]
}

extension ServerEnvironment {
    
    static let loaded: [ServerEnvironment] = {
        guard let configPath = Bundle.init(for: BaseTestClass.self).path(forResource: "config", ofType: "json") else {
            fatalError("Config file config.json is not present.")
        }
        
        do {
            let configContent = try String(contentsOfFile: configPath, encoding: .utf8)
            return try JSONDecoder().decode(ServerEnvironmentData.self, from: configContent.data(using: .utf8)!).environments
        } catch {
            fatalError("Config file config.json at path \(configPath) cannot be parsed: \(error)")
        }
    }()
}

extension WDOVerificationState {
    /// Shadow state for better comparison (to be able to do `.shadowState == .intro`)
    var shadowState: VerificationStateShadow {
        switch self {
        case .intro: return .intro
        case .documentsToScanSelect: return .documentsToScanSelect
        case .scanDocument: return .scanDocument
        case .processing: return .processing
        case .presenceCheck: return .presenceCheck
        case .otp: return .otp
        case .activationFinish: return .activationFinish
        case .failed: return .failed
        case .endstate: return .endstate
        case .success: return .success
        }
    }
}

extension WDOVerificationService.Success {
    var shadowState: VerificationStateShadow { self.state.shadowState }
}

enum VerificationStateShadow {
    case intro
    case documentsToScanSelect
    case scanDocument
    case processing
    case presenceCheck
    case otp
    case activationFinish
    case failed
    case endstate
    case success
}
