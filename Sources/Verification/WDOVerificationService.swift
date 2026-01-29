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
import PowerAuth2
import PowerAuthCore
import WultraPowerAuthNetworking

/// Service that can verify previously activated PowerAuthSDK instance.
///
/// When PowerAuthSDK instance was activated with weak credentials via `WDOActivationService`, user needs to verify his genuine presence.
/// This can be confirmed in the `PowerAuthActivationStatus.needVerification` which will be `true`.
///
/// This service operates against Wultra Onboarding server (usually ending with `/enrollment-onboarding-server`) and you need to configure networking service with the right URL.
public class WDOVerificationService {
    
    // MARK: Public Properties
    
    /// Delegate that retrieves information about the verification and activation changes.
    public weak var delegate: WDOVerificationServiceDelegate?
    
    /// Accept language for the outgoing requests headers.
    /// Default value is "en".
    ///
    /// Standard RFC "Accept-Language" https://tools.ietf.org/html/rfc7231#section-5.3.5
    /// Response texts are based on this setting. For example when "de" is set, server
    /// will return error texts and other in german (if available).
    public var acceptLanguage: String {
        get {
            return api.networking.acceptLanguage
        }
        set {
            D.debug("Setting new language for WDOVerificationService: \(newValue)")
            api.networking.acceptLanguage = newValue
        }
    }
    
    /// Time in seconds that user needs to wait between OTP resend calls
    public var otpResendPeriodInSeconds: Int? {
        guard let period = lastStatus?.config.otpResendPeriod else {
            return nil
        }
        guard let components = ISO8601DurationFormatter().dateComponents(from: period) else {
            return nil
        }
        // we're counting time only
        return (components.second ?? 0) + (60 * (components.minute ?? 0)) + (3600 * (components.hour ?? 0))
    }
    
    // MARK: - Private properties
    
    private let api: Networking
    private let keychainKey: String
    private var lastStatus: IdentityStatusResponse?
    private var cachedProcess: WDOVerificationScanProcess? {
        get {
            if let data = KeychainWrapper.standard.string(forKey: keychainKey) {
                return WDOVerificationScanProcess(cacheData: data)
            } else {
                return nil
            }
        }
        set {
            if let newValue {
                KeychainWrapper.standard.set(newValue.dataForCache(), forKey: keychainKey)
            } else {
                KeychainWrapper.standard.removeObject(forKey: keychainKey)
            }
        }
    }
    
    // MARK: - Public initializers
    
    /// Creates service instance
    /// - Parameters:
    ///   - powerAuth: Configured PowerAuthSDK instance. This instance needs to have a valid activation.
    ///   - config: Configuration of the networking service.
    public convenience init(powerAuth: PowerAuthSDK, wpnConfig: WPNConfig) {
        self.init(networking: .init(powerAuth: powerAuth, config: wpnConfig, serviceName: "WDOVerificationNetworking"))
    }
    
    /// Creates service instance
    /// - Parameters:
    ///   - networking: Networking service for the onboarding server with configured PowerAuthSDK instance that needs to have a valid activation.
    public convenience init(networking: WPNNetworkingService) {
        self.init(api: .init(networking: networking))
        if networking.powerAuth.hasValidActivation() == false {
            cachedProcess = nil
        }
    }
    
    // MARK: - Private initializers
    
    init(api: Networking) {
        self.api = api
        self.keychainKey = "wdocp_\(api.networking.powerAuth.configuration.instanceId)"
    }
    
    // MARK: - Public API
    
    /// Status of the verification.
    ///
    /// - Parameter completion: Callback with the result.
    public func status(completion: @escaping (Result<WDOVerificationState, Fail>) -> Void) {
        
        D.debug("Retrieving verification status.")
        
        api.identityVerification.getStatus { [weak self] result in
            
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            
            switch result {
            case .success(let response):
                
                D.info("Verification status successfully retrieved.")
                D.debug("\(response)")
                
                switch response.status {
                case .failed, .rejected, .notInitialized, .accepted:
                    D.debug("Status \(response.status) - clearing cache.")
                    self.cachedProcess = nil
                default:
                    break
                }
                self.lastStatus = response
                
                let vf: VerificationStatus
                do {
                    vf = try VerificationStatus.from(status: response)
                } catch {
                    D.error(error)
                    if let wpnError = error as? WPNError {
                        self.markCompleted(wpnError, completion)
                    } else {
                        self.markCompleted(.failure(Fail(.init(reason: .unknown))), completion)
                    }
                    return
                }
                
                D.info("Verification status: \(vf)")
                switch vf {
                case .intro(let consentRequired):
                    self.markCompleted(.success(.intro(consentRequired: consentRequired)), completion)
                case .documentScan:
                    D.debug("Verifying documents status")
                    self.api.identityVerification.documentsStatus(processId: response.processId) { [weak self] docsResult in
                        guard let self else {
                            completion(.failure(.init(.init(reason: .unknown))))
                            return
                        }
                        switch docsResult {
                        case .success(let docsResponse):
                            
                            D.info("Documents status retrieved.")
                            
                            let documents = docsResponse.documents
                            
                            if let cachedProcess = self.cachedProcess {
    
                                cachedProcess.feed(docsResponse.documents)
                                if documents.contains(where: { $0.action == .error }) || documents.contains(where: { $0.errors != nil && !$0.errors!.isEmpty }) {
                                    self.markCompleted(.success(.scanDocument(cachedProcess)), completion)
                                } else if documents.allSatisfy({ $0.action == .proceed }) {
                                    self.markCompleted(.success(.scanDocument(cachedProcess)), completion)
                                } else if documents.contains(where: { $0.action == .wait }) {
                                    // TODO: really verification?
                                    self.markCompleted(.success(.processing(.documentVerification)), completion)
                                } else if documents.isEmpty {
                                    self.markCompleted(.success(.scanDocument(cachedProcess)), completion)
                                } else {
                                    // TODO: is this ok?
                                    self.markCompleted(.success(.failed), completion)
                                }
                            } else {
                                if documents.isEmpty {
                                    self.markCompleted(.success(.documentsToScanSelect), completion)
                                } else {
                                    self.markCompleted(.success(.failed), completion)
                                }
                            }
                            
                        case .failure(let error):
                            D.error(error)
                            self.markCompleted(error, completion)
                        }
                    }
                case .presenceCheck:
                    self.markCompleted(.success(.presenceCheck), completion)
                case .statusCheck(let reason):
                    self.markCompleted(.success(.processing(.from(reason))), completion)
                case .otp:
                    self.markCompleted(.success(.otp(nil)), completion)
                case .activationFinish:
                    self.markCompleted(.success(.activationFinish), completion)
                case .failed:
                    self.markCompleted(.success(.failed), completion)
                case .rejected:
                    self.markCompleted(.success(.endstate(.rejected)), completion)
                case .success:
                    self.markCompleted(.success(.success), completion)
                }
            case .failure(let error):
                D.error(error)
                self.lastStatus = nil
                self.markCompleted(error, completion)
            }
        }
    }
    
    /// Returns consent text for user to approve. The content of the text depends on the server configuration and might be plain text or HTML.
    ///
    /// Consent text explains how the service will handle his document photos or selfie scans.
    ///
    /// - Parameter completion: Callback with the consent text.
    public func getConsent(completion: @escaping (Result<String, Fail>) -> Void) {
        D.debug("Getting consent.")
        guard let processId = guardProcessId(completion) else {
            return
        }
        api.identityVerification.getConsentText(processId: processId) { result in
            result.onSuccess {
                D.info("Consent data retrieved.")
                completion(.success($0))
            }.onError {
                D.error($0)
                completion(.failure(.init($0)))
            }
        }
    }
    
    /// Start the identity verification after user approved the consent (if required)
    ///
    /// - Parameters:
    ///   - consentApprovedByUser: Response of the user to the consent.
    ///   - completion: Callback with the result.
    public func start(
        consentApprovedByUser: ConsentResponse,
        completion: @escaping (Result<Success, Fail>) -> Void
    ) {
        D.debug("Starting verification with consent response: \(consentApprovedByUser.rawValue)")
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        switch consentApprovedByUser {
        case .approved:
            D.info("User approved consent - resolving on server")
            api.identityVerification.resolveConsent(processId: processId, approved: true) { [weak self] result in
                guard let self else {
                    completion(.failure(.init(.init(reason: .unknown))))
                    return
                }
                result.onSuccess {
                    D.info("Consent granted - starting verification process.")
                    self.startProcess(processId: processId, completion: completion)
                }.onError { err in
                    D.error(err)
                    self.markCompleted(err, completion)
                }
            }
        case .declined:
            D.info("User declined consent - returning to intro state")
            api.identityVerification.resolveConsent(processId: processId, approved: false) { [weak self] result in
                guard let self else {
                    completion(.failure(.init(.init(reason: .unknown))))
                    return
                }
                result.onSuccess {
                    let consentRequired = self.lastStatus?.consentRequired ?? true
                    self.markCompleted(.success(.intro(consentRequired: consentRequired)), completion)
                }.onError {
                    D.error($0)
                    self.markCompleted($0, completion)
                }
            }
        case .notRequired:
            D.info("Consent not required - start verification process immediately")
            startProcess(processId: processId, completion: completion)
        }
    }
    
    /// Get the token for the document scanning SDK, when required.
    ///
    /// This is needed for example for ZenID provider.
    ///
    /// - Parameters:
    ///   - challenge: SDK generated challenge for the server.
    ///   - completion: Callback with the token for the SDK.
    public func documentsInitSDK(challenge: String, completion: @escaping (Result<String, Fail>) -> Void) {
        
        D.debug("Initiating document scan SDK.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.initScanSDK(processId: processId, challenge: challenge) { [weak self] result in
            guard let self = self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            result.onSuccess {
                D.info("Document init successful.")
                self.markCompleted(.success($0), completion)
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Set which documents will be scanned.
    ///
    /// Note that this needs to be in sync what server expects based on the configuration.
    ///
    /// - Parameters:
    ///   - types: Types of documents to scan.
    ///   - completion: Callback with the result.
    public func documentsSetSelectedTypes(types: [WDODocumentType], completion: @escaping (Result<Success, Fail>) -> Void) {
        // TODO: We should maybe verify that we're in the expected state here?
        D.debug("Selecting document types - \(types).")
        let process = WDOVerificationScanProcess(types: types)
        cachedProcess = process
        markCompleted(.success(.scanDocument(process)), completion)
    }
    
    /// Upload document files to the server. The order of the documents is up to you. Make sure that uploaded document are reasonable size so you're not uploading large files.
    ///
    /// If you're uploading the same document file again, you need to include the `originalDocumentId` otherwise it will be rejected by the server.
    ///
    /// - Parameters:
    ///   - files: Document files to upload.
    ///   - progressCallback: Upload progress callback.
    ///   - completion: Callback with the result.
    public func documentsSubmit(files: [WDODocumentFile], progressCallback: @escaping (Double) -> Void, completion: @escaping (Result<Success, Fail>) -> Void) {
        
        D.debug("Submitting files.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = DocumentPayloadBuilder.build(processId: processId, files: files)
            self.api.identityVerification.submitDocuments(data: data, progressCallback: progressCallback) { [weak self] result in
                guard let self else {
                    completion(.failure(.init(.init(reason: .unknown))))
                    return
                }
                result.onSuccess {
                    D.info("Documents submitted")
                    self.markCompleted(.success(.processing(.documentUpload)), completion)
                }.onError {
                    D.error($0)
                    self.markCompleted($0, completion)
                }
            }
        }
    }
    
    /// Initiates the presence check. This returns attributes that are needed to start the 3rd party SDK (if needed).
    ///
    /// - Parameter completion: Callback with the result.
    public func presenceCheckInit(completion: @escaping (Result<[String: Any], Fail>) -> Void) {
        
        D.debug("Initiating presence check.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.presenceCheckInit(processId: processId) { [weak self] result in
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            result.onSuccess {
                D.info("Presence check initiated.")
                self.markCompleted(.success($0.attributes), completion)
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Call when presence check was finished in the 3rd party SDK.
    ///
    /// - Parameter completion: Callback with the result.
    public func presenceCheckSubmit(completion: @escaping (Result<Success, Fail>) -> Void) {
        
        D.debug("Marking presence check finished.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.presenceCheckSubmit(processId: processId) { [weak self] result in
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            result.onSuccess {
                D.info("Presence check submitted")
                self.markCompleted(.success(.processing(.verifyingPresence)), completion)
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Verification restart. When sucessfully called, intro screen should be presented.
    ///
    /// - Parameter completion: Callback with the result.
    public func restartVerification(completion: @escaping (Result<Success, Fail>) -> Void) {
        
        D.debug("Restarting verification process.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.cleanup(processId: processId) { [weak self] result in
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            result.onSuccess {
                D.info("Verification process restarted.")
                self.status { [weak self] statusResult in
                    guard let self else {
                        completion(.failure(.init(.init(reason: .unknown))))
                        return
                    }
                    statusResult.onSuccess {
                        self.markCompleted(.success($0), completion)
                    }.onError {
                        self.markCompleted(.failure($0), completion)
                    }
                }
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Cancel the whole activation/verification. After this it's no longer possible to call any API of this library and PowerAuth activation should be removed and activation started again.
    ///
    /// - Parameter completion: Callback with the result.
    public func cancelWholeProcess(completion: @escaping (Result<Void, Fail>) -> Void) {
        
        D.debug("Canceling whole verification process.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.onboarding.cancel(processId: processId) { [weak self] result in
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            result.onSuccess {
                D.info("Verification process was canceled.")
                self.markCompleted(.success(()), completion)
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Finishes verification by creating a new PowerAuth activation on given `newPowerAuthInstance`.
    ///
    /// Needs to be called when `activationFinish` next step is returned from the `status()` call.
    ///
    /// The method verifies that the provided `password` is the same as used in the original activation
    /// (if `validatePassword` is set to `true`), then it calls the server API to finish
    /// the verification and obtain the activation code for the new activation. Finally, it creates
    /// a new activation on the `newPowerAuthInstance` using the obtained activation code and persists it
    /// with the provided `newPassword`.
    ///
    /// After successful completion, the original PowerAuth instance becomes invalid (`removed` state) and cannot be used anymore.
    ///
    /// - Parameters:
    ///   - newPowerAuthInstance PowerAuth instance where to create new activation. This instance must not have an existing activation.
    ///   - newActivationName Name of the new activation to be created on `newPowerAuthInstance`.
    ///   - newPassword Password to protect the new activation. In case `validatePassword` is `true`, this password must match the password of the original activation.
    ///   - validatePassword If set to `true`, the method verifies that the provided `newPassword` matches the password of the original activation.
    ///   - userIdentification Optional user identification object to be sent to the server during the finish activation process.
    ///   - completion Completion with the result.
    public func finishActivation(
        newPowerAuthInstance: PowerAuthSDK,
        newActivationName: String,
        newPassword: PowerAuthCorePassword,
        validatePassword: Bool,
        userIdentification: Encodable?,
        completion: @escaping (Result<Success, Fail>) -> Void
    ) {

        D.debug("Finishing activation.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        guard newPowerAuthInstance.canStartActivation() else {
            WDOLogger.error("finishActivation - cannot activate, the `newPowerAuthInstance` is not in a state that allows it")
            completion(.failure(.init(.init(reason: .wdo_cannot_activate))))
            return
        }

        // Validate the password first (if required)
        validatePasswordIfRequired(required: validatePassword, password: newPassword) { [weak self] validateError in
            
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            
            // // Password validation failed -> report and return
            if let validateError {
                WDOLogger.error("finishActivation - password validation failed : \(validateError)")
                self.markCompleted(WPNError(reason: .wdo_password_invalid, error: validateError), completion)
                return
            }
            
            // Proceed with finish activation API call to retrieve the activation code
            self.api.identityVerification.finishActivation(processId: processId, userIdentification: userIdentification) { [weak self] result in
                
                guard let self else {
                    completion(.failure(.init(.init(reason: .unknown))))
                    return
                }
                
                // make sure we received the activation code
                guard let response = result.success else {
                    
                    let error = result.error ?? WPNError(reason: .unknown)
                    
                    // Finish activation API call failed
                    WDOLogger.error("finishActivation failed : \(error)")
                    self.markCompleted(error, completion)
                    return
                }
                    
                WDOLogger.info("finishActivation call was successful.")
                
                // Prepare PowerAuth activation with retrieved activation code
                let activation: PowerAuthActivation
                do {
                    activation = try PowerAuthActivation(
                        activationCode: response.activationCode,
                        name: newActivationName
                    )
                } catch let e {
                    // failed to create PowerAuthActivation object
                    self.markCompleted(.failure(.init(.wrap(.wdo_activation_failed, e))), completion)
                    return
                }
                
                // Create new activation on the new (fresh) instance
                newPowerAuthInstance.createActivation(activation) { [weak self] _, error in
                    
                    guard let self else {
                        completion(.failure(.init(.init(reason: .unknown))))
                        return
                    }
                    
                    // handleError helper function
                    func handleError(_ error: Error, reason: String) {
                        // clean the new instance in case the activation is in progress
                        if newPowerAuthInstance.canStartActivation() == false {
                            newPowerAuthInstance.removeActivationLocal()
                        }
                        // report the error
                        WDOLogger.error("finishActivation failed - \(reason): \(error.localizedDescription)")
                        self.markCompleted(.failure(.init(.wrap(.wdo_activation_failed, error))), completion)
                    }
                    
                    // in case of error (probably server/networking), report error
                    guard error == nil else {
                        handleError(error!, reason: "failed to create activation")
                        return
                    }
                    
                    // persist the activation with the provided password
                    do {
                        try newPowerAuthInstance.persistActivation(with: .persistWithPassword(password: newPassword))
                        self.markCompleted(.success(.success), completion)
                    } catch let e {
                        handleError(e, reason: "failed to persist activation")
                    }
                }
            }
        }
    }

    ///  Validates password if required. If not required, calls completion immediately.
    ///
    /// - Parameters:
    ///   - required Whether the password validation is required.
    ///   - password Password to validate.
    ///   - completion Callback called when the password is valid or validation is not required.
    private func validatePasswordIfRequired(
        required: Bool,
        password: PowerAuthCorePassword,
        completion: @escaping (Error?) -> Void
    ) {
        if required {
            api.networking.powerAuth.validatePassword(password: password) { error in
                completion(error)
            }
        } else {
            // Password validation not required
            completion(nil)
        }
    }
    
    /// Verify OTP that user entered as a last step of the verification.
    ///
    /// - Parameters:
    ///   - otp: OTP that user obtained via other channel (usually SMS or email).
    ///   - completion: Callback with the result.
    public func verifyOTP(otp: String, completion: @escaping (Result<Success, Fail>) -> Void) {
        
        D.debug("Verifying OTP - \(otp)")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.verifyOTP(processId: processId, otp: otp) { [weak self] result in
            
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            
            result.onSuccess { data in
                if data.verified {
                    D.info("OTP verified")
                    self.markCompleted(.success(.processing(.other)), completion)
                } else {
                    if data.remainingAttempts > 0 && data.expired == false {
                        D.error("OTP not verified. Try again")
                        self.markCompleted(.success(.otp(data.remainingAttempts)), completion)
                    } else {
                        D.error("OTP not verified.")
                        self.markCompleted(.failure(.init(.init(reason: .wdo_verification_otpFailed))), completion)
                    }
                }
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    
    /// Request OTP resend.
    ///
    /// Since SMS or emails can fail to deliver, use this to send the OTP again.
    ///
    /// - Parameter completion: Callback with the result.
    public func resendOTP(completion: @escaping (Result<Void, Fail>) -> Void) {
        
        D.debug("Resending verification OTP.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.identityVerification.resendOTP(processId: processId) { [weak self] result in
            
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            
            result.onSuccess {
                D.info("Verification OTP resend success.")
                self.markCompleted(.success(()), completion)
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    
    #if ENABLE_ONBOARDING_DEMO
    /// Demo endpoint available only in Wultra Demo systems.
    ///
    /// If the app is running against our demo server, you can retrieve the OTP without needing to send SMS or emails.
    ///
    /// - Parameter completion: Callback with the result.
    public func getOTP(completion: @escaping (Result<String, Fail>) -> Void) {
        
        D.debug("Retrieving verification OTP via non-production endpoint.")
        
        guard let processId = guardProcessId(completion) else {
            return
        }
        
        api.onboarding.getOTP(processId: processId, type: .userVerification) { [weak self] result in
            
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            
            result.onSuccess {
                D.info("Verification OTP retrieved.")
                D.debug("  - \($0)")
                self.markCompleted(.success($0), completion)
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    #endif
    
    // MARK: Public Helper Classes
    
    /// Success result with the next screen/state that should be presented to the user.
    public class Success {
        
        init(_ state: WDOVerificationState) {
            self.state = state
        }
        
        /// State of the verification for the app to display.
        public let state: WDOVerificationState
    }
    
    /// Error result with cause of the error and state that should be presented (if available).
    ///
    /// Note that state will be filled only when the error indicates state change.
    public class Fail: Error {
        
        /// Cause of the error.
        public let cause: WPNError
        /// State of the verification for app to display. If not available, error screen should be displayed.
        public let state: WDOVerificationState?
        
        init(_ cause: WPNError) {
            self.cause = cause
            switch cause.restApiError?.errorCode {
            case .onboardingFailed:
                state = .endstate(.other)
            case .identityVerificationFailed:
                state = .failed
            case .onboardingLimitReached:
                state = .endstate(.limitReached)
            case .presenceCheckLimitEached, .identityVerificationLimitReached:
                state = .failed
            default:
                state = nil
            }
        }
    }
    
    // MARK: - Private helper methods
    
    /// Function that starts the verification process on the server.
    /// Must be called once user accepted consent (if required).
    private func startProcess(
        processId: String,
        completion: @escaping (Result<Success, Fail>) -> Void
    ) {
        self.api.identityVerification.start(processId: processId) { [weak self] startResult in
            guard let self else {
                completion(.failure(.init(.init(reason: .unknown))))
                return
            }
            startResult.onSuccess {
                D.info("Verification process started")
                self.markCompleted(.success(.documentsToScanSelect), completion)
            }.onError {
                D.error($0)
                self.markCompleted($0, completion)
            }
        }
    }
    
    private func guardProcessId<T>(_ completion: (Result<T, Fail>) -> Void) -> String? {
        guard let processId = lastStatus?.processId else {
            D.error("Process id not available - did you start the verification process and fetched the status?")
            markCompleted(.failure(.init(.init(reason: .wdo_verification_missingStatus))), completion)
            return nil
        }
        return processId
    }
    
    private func markCompleted<T>(_ error: WPNError, _ completion: @escaping (Result<T, Fail>) -> Void) {
        if error.networkIsNotReachable == false || error.restApiError?.errorCode == .authenticationFailure {
            api.networking.powerAuth.fetchActivationStatus { [weak self] status, _ in
                
                guard let self else {
                    completion(.failure(.init(.init(reason: .unknown))))
                    return
                }
                
                if let status, status.state != .active {
                    D.error("PowerAuth status is not active (status\(status.state)) - notifying the delegate and returning and error.")
                    self.delegate?.powerAuthActivationStatusChanged(self, status: status)
                    self.markCompleted(.failure(.init(.init(reason: .wdo_verification_activationNotActive, error: error))), completion)
                } else {
                    D.error(error)
                    self.markCompleted(.failure(.init(error)), completion)
                }
            }
        } else {
            D.error(error)
            markCompleted(.failure(.init(error)), completion)
        }
    }
    
    private func markCompleted<T>(_ result: Result<T, Fail>, _ completion: (Result<T, Fail>) -> Void) {
        if let state = (result.success as? Success)?.state ?? result.error?.state {
            delegate?.verificationStatusChanged(self, status: state)
        }
        completion(result)
    }
}

// MARK: - Other public APIs

/// Delegate of the Onboarding Verification Service that can listen on Verification Status and PowerAuth Status changes.
public protocol WDOVerificationServiceDelegate: AnyObject {
    /// Called when PowerAuth activation status changed.
    ///
    /// Note that this happens only when error is returned in some of the Verification endpoints and this error indicates PowerAuth status change. For
    /// example when the service finds out during the API call that the PowerAuth activation was removed or blocked on the server
    func powerAuthActivationStatusChanged(_ sender: WDOVerificationService, status: PowerAuthActivationStatus)
    
    /// Called when state of the verification has changed.
    func verificationStatusChanged(_ sender: WDOVerificationService, status: WDOVerificationState)
}

public extension WPNErrorReason {
    /// Powerauth instance is not active. Verification can only happen when the user already activated the PowerAuth instance.
    static let wdo_verification_activationNotActive = WPNErrorReason(rawValue: "wdo_verification_activationNotActive")
    /// Wultra Digital Onboarding verification status is unknown. Please make sure that the status was at least once successfully fetched before calling any other method
    static let wdo_verification_missingStatus = WPNErrorReason(rawValue: "wdo_verification_missingStatus")
    /// Wultra Digital Onboarding OTP failed to verify.
    static let wdo_verification_otpFailed = WPNErrorReason(rawValue: "wdo_verification_otpFailed")
    /// Failed to validate password when finishing activation
    static let wdo_password_invalid = WPNErrorReason(rawValue: "wdo_password_invalid")
    /// Failed to create activation during the activation finish
    static let wdo_activation_failed = WPNErrorReason(rawValue: "wdo_activation_failed")
    /// Cannot finish the activation - given powerauth instance cannot start activation
    static let wdo_cannot_activate = WPNErrorReason(rawValue: "wdo_cannot_activate")
}

// MARK: - Private extensions and other

private extension Result where Success == WDOVerificationService.Success, Failure == WDOVerificationService.Fail {
    static func success(_ nextStep: WDOVerificationState) -> Self {
        return .success(WDOVerificationService.Success(nextStep))
    }
}

// Internal status that works as a translation layer between server API and SDK API
enum VerificationStatus: CustomStringConvertible {
    
    enum Reason: CustomStringConvertible {
        case unknown
        case documentUpload
        case documentVerification
        case documentAccepted
        case documentsCrossVerification
        case clientVerification
        case clientAccepted
        case onboardingApproval
        case verifyingPresence
        
        var description: String {
            return switch self {
            case .unknown: "unknown"
            case .documentUpload: "documentUpload"
            case .documentVerification: "documentVerification"
            case .documentAccepted: "documentAccepted"
            case .documentsCrossVerification: "documentsCrossVerification"
            case .clientVerification: "clientVerification"
            case .clientAccepted: "clientAccepted"
            case .verifyingPresence: "verifyingPresence"
            case .onboardingApproval: "onboardingApproval"
            }
        }
    }
    
    case intro(consentRequired: Bool)
    case documentScan
    case statusCheck(_ reason: Reason)
    case presenceCheck
    case otp
    case activationFinish
    case failed
    case rejected
    case success
    
    // Translation from server status to phone status.
    static func from(status response: IdentityStatusResponse) throws -> VerificationStatus {
        let consentRequired = response.consentRequired ?? true // on native platforms we assume consent to be required by default
        switch (response.phase, response.status) {
        case (nil, .notInitialized):                      return .intro(consentRequired: consentRequired)
        case (nil, .failed):                              return .failed
        case (.documentUpload, .inProgress):              return .documentScan
        case (.documentUpload, .verificationPending):     return .statusCheck(.documentVerification)
        case (.documentUpload, .failed):                  return .failed
        case (.documentVerification, .accepted):          return .statusCheck(.documentAccepted)
        case (.documentVerification, .inProgress):        return .statusCheck(.documentVerification)
        case (.documentVerification, .failed):            return .failed
        case (.documentVerification, .rejected):          return .rejected
        case (.documentVerificationFinal, .accepted):     return .statusCheck(.documentsCrossVerification)
        case (.documentVerificationFinal, .inProgress):   return .statusCheck(.documentsCrossVerification)
        case (.documentVerificationFinal, .failed):       return .failed
        case (.documentVerificationFinal, .rejected):     return .rejected
        case (.clientEvaluation, .inProgress):            return .statusCheck(.clientVerification)
        case (.clientEvaluation, .accepted):              return .statusCheck(.clientAccepted)
        case (.clientEvaluation, .rejected):              return .rejected
        case (.clientEvaluation, .failed):                return .failed
        case (.presenceCheck, .notInitialized):           return .presenceCheck
        case (.presenceCheck, .inProgress):               return .presenceCheck
        case (.presenceCheck, .verificationPending):      return .statusCheck(.verifyingPresence)
        case (.presenceCheck, .failed):                   return .failed
        case (.presenceCheck, .rejected):                 return .rejected
        case (.otp, .verificationPending):                return .otp
        case (.onboardingApproval, .rejected):            return .rejected
        case (.onboardingApproval, .failed):              return .failed
        case (.onboardingApproval, .accepted):            return .statusCheck(.onboardingApproval)
        case (.onboardingApproval, .inProgress):          return .statusCheck(.onboardingApproval)
        case (.onboardingApproval, .verificationPending): return .statusCheck(.onboardingApproval)
        case (.onboardingApproval, .notInitialized):      return .statusCheck(.onboardingApproval)
        case (.completed, .accepted):                     return .success
        case (.completed, .failed):                       return .failed
        case (.completed, .rejected):                     return .rejected
        default:
            // special case where we dont care about the status...
            if response.phase == .activationFinish {
                return .activationFinish
            } else {
                throw WPNError(
                    reason: WPNErrorReason.unknown,
                    error: WDOError(message: "Unknown phase/status combo: \(response.phase?.rawValue ?? "nil"), \(response.status.rawValue)")
                )
            }
        }
    }
    
    var description: String {
        let name = switch self {
        case .intro(let consentRequired): "intro(consentRequired: \(consentRequired))"
        case .documentScan: "documentScan"
        case .statusCheck(let reason): "statusCheck(\(reason)"
        case .presenceCheck: "presenceCheck"
        case .otp: "otp"
        case .failed: "failed"
        case .rejected: "rejected"
        case .success: "success"
        case .activationFinish: "activationFinish"
        }
        return "VerificationStatus.\(name)"
    }
}
