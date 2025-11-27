//
// Copyright 2025 Wultra s.r.o.
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

/// Service that provides configuration for the Wultra Digital Onboarding SDK.
public class WDOConfigurationService {
    
    // MARK: - Dependencies and constants
    
    private let api: Networking
    
    // MARK: - Public initializers
    
    /// Creates service instance
    /// - Parameters:
    ///   - powerAuth: Configured PowerAuthSDK instance. This instance needs to be without valid activation.
    ///   - config: Configuration for the networking.
    public convenience init(powerAuth: PowerAuthSDK, config: WPNConfig) {
        self.init(
            networking: WPNNetworkingService(powerAuth: powerAuth, config: config, serviceName: "WDOConfigurationNetworking")
        )
    }
    
    /// Creates service instance
    /// - Parameters:
    ///   - networking: Networking service for the onboarding server with configured PowerAuthSDK instance that needs to be without valid activation.
    public convenience init(networking: WPNNetworkingService) {
        self.init(api: .init(networking: networking))
    }
    
    // MARK: - Private initializer
    
    init(api: Networking) {
        self.api = api
    }
    
    // MARK: - Public API
    
    /// Fetches configuration for the given process type from the server.
    /// - Parameters:
    ///   - processType: Type of the process for which to fetch configuration.
    ///   - completion: Configuration response from the server.
    public func getConfiguration(
        processType: String,
        completion: @escaping (Result<ConfigurationResponse, WPNError>) -> Void
    ) {
        D.debug("Get configuration for process type: \(processType)")
        
        api.configuration.getConfiguration(request: .init(processType: processType)) { result in
            result.onSuccess {
                D.info("Configuration data retrieved.")
                completion(.success($0))
            }.onError {
                D.error($0)
                let error = WPNError(reason: .unknown, error: $0)
                completion(.failure(error))
            }
        }
    }
}
