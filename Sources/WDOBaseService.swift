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

import WultraPowerAuthNetworking
import PowerAuth2

/// Base class for main customer-facing services
public class WDOBaseService {
    
    /// Accept language for the outgoing requests headers.
    /// The default value is "en".
    ///
    /// Standard RFC "Accept-Language" https://tools.ietf.org/html/rfc7231#section-5.3.5
    /// Response texts are based on this setting. For example, when "de" is set, server
    /// will return error texts and other in German (if available).
    public var acceptLanguage: String {
        get {
            return api.networking.acceptLanguage
        }
        set {
            D.debug("Setting new language for \(Self.serviceName): \(newValue)")
            api.networking.acceptLanguage = newValue
        }
    }
    
    /// Networking object that provides communication with the server.
    public var networking: WPNNetworkingService { api.networking }
    
    internal let api: Networking
    
    // MARK: - Public initializers
    
    /// Creates service instance
    ///
    /// - Parameters:
    ///   - powerAuth: Configured PowerAuthSDK instance.
    ///   - networkingConfig: Configuration of the networking service.
    public init(powerAuth: PowerAuthSDK, networkingConfig: WPNConfig) {
        api = .init(
            networking: Self.createApi(powerAuth: powerAuth, networkingConfig: networkingConfig)
        )
    }
    
    /// Creates service instance
    ///
    /// - Parameters:
    ///   - networking: Networking service for the onboarding server with configured PowerAuthSDK instance.
    public init(networking: WPNNetworkingService) {
        api = .init(
            networking: networking
        )
    }
    
    // MARK: - Private initializers
    
    init(api: Networking) {
        self.api = api
    }
    
    // MARK: - Test Features
    
    #if DEBUG
    /// Internal processing callback only for testing purposes!
    /// This callback can be set only in DEBUG build and is called during the process.
    /// Use this when some internal testing needs to be done during integration tests.
    internal var _testing_Callback: ((_ name: String, _ data: Any) -> Void)?
    #else
    internal var _testing_Callback: ((_ name: String, _ data: Any) -> Void)? {
        // no-op for non-debug
        get { nil }
        set { }
    }
    #endif
}

// MARK: - Internal Helpers

internal extension WDOBaseService {
    /// Name of the service based on the type
    static var serviceName: String { "\(self)" }

    /// Helper factory method for WPNNetworkingService
    static func createApi(powerAuth: PowerAuthSDK, networkingConfig: WPNConfig) -> WPNNetworkingService {
        return .init(
            powerAuth: powerAuth,
            config: networkingConfig,
            serviceName: "\(Self.serviceName)_networking"
        )
    }
}
