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

enum Endpoints {
    enum Onboarding {
        enum Start<TRequest: Codable> {
            typealias EndpointType = WPNEndpointBasic<WPNRequest<StartOnboardingRequest<TRequest>>, WPNResponse<ProcessResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/onboarding/start", e2ee: .applicationScope) }
        }
        enum Cancel {
            typealias EndpointType = WPNEndpointBasic<WPNRequest<ProcessRequest>, WPNResponseBase>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/onboarding/cleanup", e2ee: .applicationScope) }
        }
        enum ResendOTP {
            typealias EndpointType = WPNEndpointBasic<WPNRequest<ProcessRequest>, WPNResponseBase>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/onboarding/otp/resend", e2ee: .applicationScope) }
        }
        enum GetStatus {
            typealias EndpointType = WPNEndpointBasic<WPNRequest<ProcessRequest>, WPNResponse<ProcessResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/onboarding/status", e2ee: .applicationScope) }
        }
    }
    enum Identification {
        enum GetStatus {
            typealias EndpointType = WPNEndpointSignedWithToken<WPNRequest<EmptyRequest>, WPNResponse<IdentityStatusResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/status", tokenName: "possession_universal") }
        }
        enum StartReVerification<TIdentification: Codable> {
            typealias EndpointType = WPNEndpointSigned<WPNRequest<StartReVerificationRequest<TIdentification>>, WPNResponse<ProcessResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/onboarding/start", uriId: "/api/onboarding/start", e2ee: .activationScope) }
        }
        enum Init {
            typealias EndpointType = WPNEndpointSigned<WPNRequest<IdentityInitRequest>, WPNResponseBase>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/init", uriId: "/api/identity/init") }
        }
        enum Cancel {
            typealias EndpointType = WPNEndpointSigned<WPNRequest<ProcessRequest>, WPNResponseBase>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/cleanup", uriId: "/api/identity/cleanup") }
        }
        enum ConsentText {
            typealias EndpointType = WPNEndpointSignedWithToken<WPNRequest<ConsentTextRequest>, WPNResponse<ConsentTextResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/consent/text", tokenName: "possession_universal") }
        }
        enum ConsentApprove {
            typealias EndpointType = WPNEndpointSigned<WPNRequest<ConsentApproveRequest>, WPNResponseBase>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/consent/approve", uriId: "/api/identity/consent/approve") }
        }
        enum DocumentScanSdkInit {
            typealias EndpointType = WPNEndpointSigned<WPNRequest<SDKInitRequest>, WPNResponse<SDKInitResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/document/init-sdk", uriId: "/api/identity/document/init-sdk", e2ee: .activationScope) }
        }
        enum SubmitDocumentsV2 {
            typealias EndpointType = WPNEndpointSignedWithToken<WPNRequest<DocumentSubmitRequest>, WPNResponseBase>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/v2/identity/document/submit", tokenName: "possession_universal", e2ee: .activationScope) }
        }
        enum DocumentsStatus {
            typealias EndpointType = WPNEndpointSignedWithToken<WPNRequest<ProcessRequest>, WPNResponse<DocumentStatusResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/document/status", tokenName: "possession_universal") }
        }
        enum PresenceCheckInit {
            typealias EndpointType = WPNEndpointSigned<WPNRequest<ProcessRequest>, WPNResponse<PresenceCheckInitResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/presence-check/init", uriId: "/api/identity/presence-check/init", e2ee: .activationScope) }
        }
        enum PresenceCheckSubmit {
            typealias EndpointType = WPNEndpointSigned<WPNRequest<ProcessRequest>, WPNResponseBase>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/presence-check/submit", uriId: "/api/identity/presence-check/submit") }
        }
        enum ResendOTP {
            typealias EndpointType = WPNEndpointSigned<WPNRequest<ProcessRequest>, WPNResponseBase>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/otp/resend", uriId: "/api/identity/otp/resend") }
        }
        enum VerifyOTP {
            typealias EndpointType = WPNEndpointBasic<WPNRequest<VerifyOTPRequest>, WPNResponse<VerifyOTPResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/otp/verify", e2ee: .activationScope) }
        }
        enum ActivationFinish {
            typealias EndpointType = WPNEndpointSignedWithToken<WPNRequest<ActivationFinishRequest>, WPNResponse<ActivationFinishResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/identity/activation", tokenName: "possession_universal", e2ee: .activationScope) }
        }
    }
    enum Configuration {
        enum GetConfiguration {
            typealias EndpointType = WPNEndpointBasic<WPNRequest<WDOConfigurationRequest>, WPNResponse<WDOConfigurationResponse>>
            static var endpoint: EndpointType { .init(endpointURLPath: "/api/configuration", e2ee: .applicationScope) }
        }
    }
}

/// Some Endpoints require empty JSON object, so this is it.
struct EmptyRequest: Codable {
    
}
