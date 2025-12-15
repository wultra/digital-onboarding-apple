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

/// Object that starts the identification. Generic parameter T is whatever
/// your backend needs for authentication
struct StartOnboardingRequest<T: Codable>: Codable {
    let identification: T
    let processType: String?
}

/// For request that needs to identify the current process.
struct ProcessRequest: Codable {
    let processId: String
}

/// Onboarding process response
struct ProcessResponse: Codable {
    /// ID of the process
    let processId: String
    /// Status of the process
    let onboardingStatus: OnboardingStatus
    /// Activation code used during the activation process.
    /// If not present, the activation is created later on in the onboarding process.
    let activationCode: String?
}

/// Status of the onboarding
enum OnboardingStatus: String, Codable {
    case activationInProgress = "ACTIVATION_IN_PROGRESS"
    case verificationInProgress = "VERIFICATION_IN_PROGRESS"
    case failed = "FAILED"
    case finished = "FINISHED"
}
