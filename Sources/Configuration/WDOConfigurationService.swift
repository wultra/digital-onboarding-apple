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
public class WDOConfigurationService: WDOBaseService {
    
    // MARK: - Public API
    
    /// Fetches configuration for the given process type from the server.
    /// - Parameters:
    ///   - processType: Type of the process for which to fetch configuration.
    ///   - completion: Configuration response from the server.
    public func getConfiguration(
        processType: String,
        completion: @escaping (Result<WDOConfigurationResponse, WPNError>) -> Void
    ) {
        D.debug("Get configuration for process type: \(processType)")
        
        api.configuration.getConfiguration(request: .init(processType: processType)) { result in
            result.onSuccess {
                D.info("Configuration data retrieved.")
                completion(.success($0))
            }.onError {
                D.error($0)
                completion(.failure($0))
            }
        }
    }
}

// -- MARK: Async API

public extension WDOConfigurationService {
    /// Fetches configuration for the given process type from the server.
    ///
    /// - Parameters:
    ///   - processType: Type of the process for which to fetch configuration.
    ///
    /// - Returns: Configuration response from the server
    ///
    /// - Throws: Networking or PowerAuth error
    func getConfiguration(processType: String) async throws -> WDOConfigurationResponse {
        try await withCheckedThrowingContinuation { cont in
            getConfiguration(processType: processType) { result in
                cont.resume(with: result)
            }
        }
    }
}
