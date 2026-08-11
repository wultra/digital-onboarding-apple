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

/// Activation data used in PowerAuth activation process (`createActivation` method).
public protocol WDOActivationData {
    /// Process ID retrieved from the `WDOActivationService`.
    var processId: String { get }
    /// Attributes needed for the PowerAuth activation.
    func asAttributes() -> [String: String]
}

public extension PowerAuthSDK {
    
    /// Creates PowerAuth activation based on the data in the `WDOActivationData` object.
    ///
    /// - Parameters:
    ///   - data: Custom activation data.
    ///   - name: Name of the activation (usually device name, for example "John's iPhone").
    ///   - callback: Result callback.
    /// - Throws: An error when activation data cannot be constructed.
    /// - Returns: Operation task.
    @discardableResult
    func createActivation(
        data: WDOActivationData,
        name: String,
        callback: @escaping (Result<PowerAuthActivationResult, Error>) -> Void
    ) throws -> PowerAuthOperationTask? {
        let activation = try PowerAuthActivation(identityAttributes: data.asAttributes(), name: name)
        return createActivation(activation) { result, error in
            if let result = result {
                callback(.success(result))
            } else {
                callback(.failure(error ?? WDOError(message: "Activation failed without result and error.")))
            }
        }
    }

    /// Creates PowerAuth activation based on the activation code and OTP.
    ///
    /// - Parameters:
    ///   - activationCode: Activation code.
    ///   - otp: One time password.
    ///   - activationName: Name of activation.
    ///   - callback: Result callback.
    /// - Throws: An error when activation data cannot be constructed.
    /// - Returns: Operation task.
    @discardableResult
    func createActivation(
        activationCode: String,
        otp: String?,
        activationName: String,
        callback: @escaping (Result<PowerAuthActivationResult, Error>) -> Void
    ) throws -> PowerAuthOperationTask? {
        let activation = try PowerAuthActivation(activationCode: activationCode, name: activationName)
        if let otp = otp {
            activation.with(additionalActivationOtp: otp)
        }

        return createActivation(activation) { result, error in
            if let result = result {
                callback(.success(result))
            } else {
                callback(.failure(error ?? WDOError(message: "Activation failed without result and error.")))
            }
        }
    }
}

public extension PowerAuthActivationStatus {
    
    /// When true, activation needs to be verified via `WDOVerificationService`.
    var needVerification: Bool { verificationPending || verificationInProgress }
    
    /// Identity Verification is waiting to start.
    var verificationPending: Bool { activationFlags.contains("VERIFICATION_PENDING") }
    
    /// Identity Verification was already started by the user
    var verificationInProgress: Bool { activationFlags.contains("VERIFICATION_IN_PROGRESS") }
    
    /// When true, this already active activation is going through a re-verification (Re-KYC) process,
    /// triggered via `WDOVerificationService.startReVerification`.
    var needReVerification: Bool { reKycInProgress }
    
    /// Re-verification (Re-KYC) identity verification process was already initialized by the user.
    var reKycInProgress: Bool { activationFlags.contains("RE_KYC_IN_PROGRESS") }
    
    internal var activationFlags: [String] { customObject?["activationFlags"] as? [String] ?? [] }
}
