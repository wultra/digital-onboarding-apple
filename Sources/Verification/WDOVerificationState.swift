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

/// State which should be presented to the user. Each state represents a separate screen UI that should be presented to the user.
public enum WDOVerificationState: CustomStringConvertible {
    
    /// Show the verification introduction screen where the user can start the activation.
    /// For native platforms we assume consentRequired to be true by default.
    ///
    /// The next step should be calling the `start`.
    case intro(consentRequired: Bool = true)
    
    /// Show document selection to the user. Which documents are available and how many
    /// can the user select is up to your backend configuration.
    ///
    /// The next step should be calling the `documentsSetSelectedTypes`.
    case documentsToScanSelect
    
    /// User should scan documents - display UI for the user to scan all necessary documents.
    ///
    /// The next step should be calling the `documentsSubmit`.
    case scanDocument(_ process: WDOVerificationScanProcess)
    
    /// The system is processing data - show loading with text hint from provided `ProcessingItem`.
    ///
    /// The next step should be calling the `status`.
    case processing(_ item: ProcessingItem)
    
    /// The user should be presented with a presence check.
    /// Presence check is handled by third-party SDK based on the project setup.
    ///
    /// The next step should be calling the `presenceCheckInit` to start the check and `presenceCheckSubmit` to
    /// mark it finished  Note that these methods won't change the status and it's up to the app to handle the process of the presence check.
    case presenceCheck
    
    /// Show enter OTP screen with resend button.
    ///
    /// The next step should be calling the `verifyOTP` with user-entered OTP.
    /// The OTP is usually SMS or email.
    ///
    /// - `remainingAttempts`: Number of remaining attempts to enter the correct OTP. Available after a failed OTP attempt.
    case otp(remainingAttempts: Int?)
    
    /// Show "finish activation" with PIN prompt screen.
    ///
    /// The next step should be calling the `finishActivation` with user entered PIN.
    case activationFinish
    
    /// Verification failed and can be restarted
    ///
    /// The next step should be calling the `restartVerification` or `cancelWholeProcess` based on
    /// the user's decision if he wants to try it again or cancel the process.
    case failed
    
    /// Verification is canceled and the user needs to start again with a new PowerAuth activation.
    ///
    /// The next step should be calling the `PowerAuthSDK.removeActivationLocal()` and starting activation from scratch.
    ///
    /// - `rejectReason`: When the reason is `rejected`, this may contain the rejection reason provided by the server.
    case endstate(_ reason: EndstateReason, rejectReason: String?)
    
    /// Verification was successfully ended. Continue into your app
    case success
    
    /// The reason for what we are waiting for. For example, we can wait for documents to be OCRed and matched against the database.
    /// Use these values for better loading texts to tell the user what is happening - some tasks may take some time and see just
    /// spinning loader might be frustrating for the user.
    public enum ProcessingItem: CustomStringConvertible {
        
        /// Reason cannot be specified - show generic "Loading" text or similar.
        case other
        /// Documents are being uploaded to a internal systems
        case documentUpload
        /// Documents are being verified
        case documentVerification
        /// Documents were accepted and we're waiting for a process change
        case documentAccepted
        /// Uploaded are being cross-checked if the're issues for the same person.
        case documentsCrossVerification
        /// Verifying presence of the user infront of the phone (selfie verification).
        case verifyingPresence
        /// Client data provided are being verified by the system.
        case clientVerification
        /// Client data were accepted and we're waiting for a process change
        case clientAccepted
        /// Waiting for onboarding approval. Usually waiting for manual approval in a backoffice system.
        case onboardingApproval
        
        public var description: String {
            let prefix = "WDOVerificationState.ProcessingItem"
            switch self {
            case .other: return "\(prefix).other"
            case .documentUpload: return "\(prefix).documentUpload"
            case .documentVerification: return "\(prefix).documentVerification"
            case .documentAccepted: return "\(prefix).documentAccepted"
            case .documentsCrossVerification: return "\(prefix).documentsCrossVerification"
            case .clientVerification: return "\(prefix).clientVerification"
            case .clientAccepted: return "\(prefix).clientAccepted"
            case .verifyingPresence: return "\(prefix).verifyingPresence"
            case .onboardingApproval: return "\(prefix).onboardingApproval"
                
            }
        }
    }
    
    /// The reason why the process ended in a non-recoverable state.
    public enum EndstateReason: CustomStringConvertible {
        
        /// The verification was rejected by the system
        ///
        /// eg: Fake information, fraud detection, or user is trying repeatedly in a short time.
        /// The real reason is not presented to the user and is only audited on the server.
        case rejected
        
        /// The limit of repeat tries was reached. There is a fixed number of tries that the user can reach
        /// before the system stops the process.
        case limitReached
        
        /// An unknown reason.
        case other
        
        public var description: String {
            let prefix = "WDOVerificationState.EndstateReason"
            switch self {
            case .limitReached: return "\(prefix).limitReached"
            case .other: return "\(prefix).other"
            case .rejected: return "\(prefix).rejected"
            }
        }
    }
    
    public var description: String {
        let prefix = "WDOVerificationState"
        switch self {
        case .intro(let consentRequired): return "\(prefix).intro(consentRequired: \(consentRequired))"
        case .documentsToScanSelect: return "\(prefix).documentsToScanSelect"
        case .scanDocument: return "\(prefix).scanDocument"
        case .processing(let reason): return "\(prefix).processing:\(reason)"
        case .presenceCheck: return "\(prefix).presenceCheck"
        case .otp: return "\(prefix).otp"
        case .failed: return "\(prefix).failed"
        case .endstate: return "\(prefix).endstate"
        case .success: return "\(prefix).success"
        case .activationFinish: return "\(prefix).activationFinish"
        }
    }
}

extension WDOVerificationState.ProcessingItem {
    static func from(_ reason: VerificationStatus.Reason) -> Self {
        switch reason {
        case .unknown: return .other
        case .documentUpload: return .documentUpload
        case .documentVerification: return .documentVerification
        case .documentAccepted: return .documentAccepted
        case .documentsCrossVerification: return .documentsCrossVerification
        case .clientVerification: return .clientVerification
        case .clientAccepted: return .clientAccepted
        case .verifyingPresence: return .verifyingPresence
        case .onboardingApproval: return .onboardingApproval
        }
    }
}
