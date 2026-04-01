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
import WultraPowerAuthNetworking

#if ENABLE_ONBOARDING_DEMO

/**
 THIS FILE CONTAINS STUFF THAT WE NEED FOR DEMO TEST PURPOSES
*/

/// Strategy where `getOTP` endpoint is located
public enum WDOGetOTPEndpointStrategy {
    
    /// Part of the enrollment-onboarding-server
    case eso
    
    /// Mock server - automatic.
    ///
    /// For example, when `deployement-mtoken-eso-dev.test.com` is the url of the ESO server
    /// Then path to the mock API is `deployement-mtoken-eso-mock-dev.test.com/otp/detail`.
    ///
    /// This is a convention by wultra DevOps. If the deployment is different, use `custom` for the exact url
    case automaticMock
    
    /// Exact url of the OTP endpoint (path including!).
    case custom(url: URL)
}

extension Endpoints {
    // this endpoint is available only in our own implementation and should be available only for debug
    enum GetOTP {
        typealias EndpointType = WPNEndpointBasic<WPNRequest<OTPDetailRequest>, WPNResponse<OTPDetailResponse>>
        static var endpoint: EndpointType { WPNEndpointBasic(endpointURLPath: "/api/onboarding/otp/detail", e2ee: .applicationScope) }
    }
}

struct OTPDetailResponse: Codable {
    let otpCode: String
}

struct OTPDetailRequest: Codable {
    let processId: String
    let otpType: OTPDetailType
}

enum OTPDetailType: String, Codable {
    case activation = "ACTIVATION"
    case userVerification = "USER_VERIFICATION"
}

#endif
