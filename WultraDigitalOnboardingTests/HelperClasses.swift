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

class TestHelper {
    
    let powerAuth: PowerAuthSDK
    let activation: WDOActivationService
    let verification: WDOVerificationService
    let configuration: WDOConfigurationService
    let processType: String
    /// Credentials used for activation (set after `startAndActivate`).
    private(set) var lastCredentials: SampleCredentials?

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
        self.activation = WDOActivationService(powerAuth: powerAuth, networkingConfig: .init(baseUrl: url))
        self.verification = WDOVerificationService(powerAuth: powerAuth, networkingConfig: .init(baseUrl: url))
        self.configuration = WDOConfigurationService(powerAuth: powerAuth, networkingConfig: .init(baseUrl: url))
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

        lastCredentials = credentials
        let config = try await getConfig()
        try await start(credentials: credentials)
        
        // get otp when required
        let otp = config.otpForIdentification ? try await activation.getOTP(strategy: environment.otpGetDetailStrategy) : nil
        try await activate(otp: otp)
        
        let consent: Bool
        if case .intro(let consentRequired) = try await verification.status().state {
            consent = consentRequired
        } else {
            throw SimpleError("Unexpected status")
        }
        
        return (config, consent)
    }

    /// Runs `startAndActivate()` and then completes the whole verification flow
    func startAndActivateAndVerify(credentials: SampleCredentials = .demo()) async throws -> PowerAuthSDK? {
        guard let (config, consentRequired) = try await startAndActivate(credentials: credentials) else {
            return nil
        }

        let startResult = try await verification.start(consentApprovedByUser: consentRequired ? .approved : .notRequired)
        guard startResult.shadowState == .documentsToScanSelect else {
            throw SimpleError("[\(processType)] Expected documentsToScanSelect after start(), got: \(startResult.shadowState)")
        }

        let documentsToScan = config.getDocumentsToScan()
        _ = try await verification.documentsSetSelectedTypes(types: documentsToScan.map { $0.patchedType })

        guard environment.servicesMock else {
            print("[\(processType)] Cannot complete verification to success — servicesMock is disabled for '\(environment.name)'")
            return nil
        }

        func waitForNonProcessingStatus() async throws -> WDOVerificationState {
            let pollIntervalSeconds: Double = 3
            let maxRetries = 10
            var retryCount = 0

            var statusResult = try await verification.status()
            while statusResult.state.shadowState == .processing {
                guard retryCount < maxRetries else {
                    throw SimpleError("[\(processType)] Processing did not finish after \(maxRetries) retries (\(Int(Double(maxRetries) * pollIntervalSeconds)) s)")
                }
                retryCount += 1
                try await Task.sleep(for: .seconds(pollIntervalSeconds))
                statusResult = try await verification.status()
            }
            return statusResult.state
        }

        var state = try await waitForNonProcessingStatus()

        if state.shadowState == .scanDocument {
            for doc in documentsToScan {
                _ = try await verification.documentsSubmit(files: try doc.uploadFiles())
                state = try await waitForNonProcessingStatus()
            }
        }

        if state.shadowState == .presenceCheck {
            _ = try await verification.presenceCheckInit()
            _ = try await verification.presenceCheckSubmit()
            state = try await waitForNonProcessingStatus()
        }

        if state.shadowState == .otp {
            let otp = try await verification.getOTP(strategy: environment.otpGetDetailStrategy)
            let otpResult = try await verification.verifyOTP(otp: otp)
            state = otpResult.state
            if state.shadowState == .processing {
                state = try await waitForNonProcessingStatus()
            }
        }

        var activePowerAuth = powerAuth

        if state.shadowState == .activationFinish {
            guard let newPa = PowerAuthSDK(configuration: .init(
                instanceId: UUID().uuidString,
                baseEndpointUrl: environment.esUrl,
                configuration: environment.mobileConfig
            )) else {
                throw SimpleError("[\(processType)] Failed to create PowerAuthSDK for activation finish")
            }
            let password = PowerAuthCorePassword(string: "1234")
            let finishResult = try await verification.finishActivation(
                newPowerAuthInstance: newPa,
                newActivationName: UIDevice.current.name,
                newPassword: password,
                validatePassword: false,
                userIdentification: nil
            )
            state = finishResult.state
            activePowerAuth = newPa
        }

        guard state.shadowState == .success else {
            throw SimpleError("[\(processType)] Expected success after completing verification, got: \(state.shadowState)")
        }

        return activePowerAuth
    }

    func assertVerificationState(_ expectedState: VerificationStateShadow) async throws {
        let status = try await verification.status()
        #expect(status.state.shadowState == expectedState)
    }
    
    /// Creates an activation via a PowerAuth activation code obtained from the PowerAuth Cloud admin API,
    /// bypassing the onboarding process entirely - used by Re-KYC tests to obtain an activation that was
    /// not created through onboarding.
    func prepareCodeActivation(userId: String = UUID().uuidString) async throws {
        guard let cloudServerUrl = environment.cloudServerUrl, let cloudServerLogin = environment.cloudServerLogin, let cloudServerPassword = environment.cloudServerPassword, let cloudApplicationId = environment.cloudApplicationId else {
            throw SimpleError("Cloud admin API is not configured for the environment '\(environment.name)'")
        }
        
        struct RegistrationResponse: Decodable {
            let registrationId: String
            let activationCode: String
        }
        
        let body = """
        {
          "appId": "\(cloudApplicationId)",
          "userId": "\(userId)",
          "commitPhase": "ON_KEY_EXCHANGE"
        }
        """
        
        let url = URL(string: "\(cloudServerUrl)/v2/registrations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)
        let credentials = "\(cloudServerLogin):\(cloudServerPassword)"
        request.setValue("Basic \(Data(credentials.utf8).base64EncodedString())", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SimpleError("Cloud admin registration failed: \(String(decoding: data, as: UTF8.self))")
        }
        let registration = try JSONDecoder().decode(RegistrationResponse.self, from: data)
        
        let paActivation = try PowerAuthActivation(activationCode: registration.activationCode, name: UUID().uuidString)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            powerAuth.createActivation(paActivation) { _, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
        try powerAuth.persist()
        
        let paStatus = try await powerAuth.fetchActivationStatus()
        #expect(paStatus.state == .active)
        #expect(!paStatus.needVerification)
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
    let otpMock: String
    let servicesMock: Bool
    let reKycProcessType: String
    /// PowerAuth Cloud admin API connection, used to create an activation code directly via
    /// `POST /v2/registrations`, bypassing the onboarding process. Required for Re-KYC tests.
    let cloudServerUrl: String?
    let cloudServerLogin: String?
    let cloudServerPassword: String?
    let cloudApplicationId: String?
    
    var otpGetDetailStrategy: WDOGetOTPEndpointStrategy {
        if otpMock.uppercased() == "ESO" {
            return .eso
        } else if otpMock.uppercased() == "AUTO" {
            return .automaticMock
        } else {
            guard let url = URL(string: otpMock) else {
                D.fatalError("Invalid URL set to otpMock")
            }
            return .custom(url: url)
        }
    }
    
    init(name: String, processTypes: [String], esUrl: String, esoUrl: String, config: String, otpMock: String, servicesMock: Bool, reKycProcessType: String, cloudServerUrl: String? = nil, cloudServerLogin: String? = nil, cloudServerPassword: String? = nil, cloudApplicationId: String? = nil) {
        self.name = name
        self.processTypes = processTypes
        self.esUrl = esUrl
        self.esoUrl = esoUrl
        self.mobileConfig = config
        self.otpMock = otpMock
        self.servicesMock = servicesMock
        self.reKycProcessType = reKycProcessType
        self.cloudServerUrl = cloudServerUrl
        self.cloudServerLogin = cloudServerLogin
        self.cloudServerPassword = cloudServerPassword
        self.cloudApplicationId = cloudApplicationId
    }
    
    enum CodingKeys: String, CodingKey {
        case name, processTypes, esUrl, esoUrl, mobileConfig, otpMock, servicesMock, reKycProcessType
        case cloudServerUrl, cloudServerLogin, cloudServerPassword, cloudApplicationId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        processTypes = try container.decode([String].self, forKey: .processTypes)
        esUrl = try container.decode(String.self, forKey: .esUrl)
        esoUrl = try container.decode(String.self, forKey: .esoUrl)
        mobileConfig = try container.decode(String.self, forKey: .mobileConfig)
        otpMock = try container.decode(String.self, forKey: .otpMock)
        servicesMock = try container.decode(Bool.self, forKey: .servicesMock)
        reKycProcessType = try container.decodeIfPresent(String.self, forKey: .reKycProcessType) ?? "re-kyc"
        cloudServerUrl = try container.decodeIfPresent(String.self, forKey: .cloudServerUrl)
        cloudServerLogin = try container.decodeIfPresent(String.self, forKey: .cloudServerLogin)
        cloudServerPassword = try container.decodeIfPresent(String.self, forKey: .cloudServerPassword)
        cloudApplicationId = try container.decodeIfPresent(String.self, forKey: .cloudApplicationId)
    }
}

extension ServerEnvironment: CustomTestStringConvertible {
    /// Avoids leaking credentials in test logs/failures (Swift Testing prints arguments by default).
    var testDescription: String { "ServerEnvironment(name: \"\(name)\")" }
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

extension WDOConfigurationDocument {
    // TODO: Remove me after 2026
    // There was a BUG on a server, where driving license was named incorrectly
    // This fixes it in environments where it wasn't deployed yet.
    var patchedType: WDODocumentType {
        if type == "DRIVING_LICENCE" {
            return "DRIVING_LICENSE"
        }
        return type
    }

    /// Returns test data for given document.
    /// It is expected that the receiver is a mock service. Sending just the JSON instruction for the mock server.
    func getMockDocumentToUpload(side: WDODocumentSide) throws -> WDODocumentFile {

        let mockType: String

        switch patchedType {
        case "DRIVING_LICENSE": mockType = "Dl"
        case "ID_CARD": mockType = "Id"
        case "PASSPORT": mockType = "Passport"
        default: throw SimpleError("Unsupported \(patchedType) document type for testing")
        }

        let json = "{\"type\": \"\(mockType)\", \"isoAlpha3CountryCode\": \"\(country ?? "CZE")\"}"

        guard let data = json.data(using: .utf8) else {
            throw SimpleError("Failed to encode json to Data for \(patchedType): \(json)")
        }

        return WDODocumentFile(data: data, type: patchedType, side: side, originalDocumentId: nil, dataSignature: nil)
    }

    /// Builds the mock file(s) for a document upload, covering both sides when the document requires it.
    func uploadFiles() throws -> [WDODocumentFile] {
        var files = [try getMockDocumentToUpload(side: .front)]
        if sideCount == 2 {
            files.append(try getMockDocumentToUpload(side: .back))
        }
        return files
    }
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
