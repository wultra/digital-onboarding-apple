//
//  WultraDigitalOnboardingTests.swift
//  WultraDigitalOnboardingTests
//
//  Created by Jan Kobersky on 30.01.2026.
//

import Testing
import System
import PowerAuth2
@testable import WultraDigitalOnboarding
internal import WultraPowerAuthNetworking

struct SimpleError: Error {
    
    private(set) var localizedDescription = ""
    
    init(_ message: String) {
        self.localizedDescription = message
    }
}

struct WultraDigitalOnboardingTests {
    
    private let powerAuth: PowerAuthSDK
    private let activation: WDOActivationService
    private let verification: WDOVerificationService
    private let configuration: WDOConfigurationService
    private let processTypes = ["onboarding", "reactivation"]
    private let esUrl = ""
    private let esoUrl = ""
    private let mobileConfig = ""
    
    init() throws {
        guard let pa = PowerAuthSDK(
            configuration: .init(
                instanceId: UUID().uuidString,
                baseEndpointUrl: esUrl,
                configuration: mobileConfig
            )
        ) else {
            throw SimpleError("Faield to create PowerAuthSDK")
        }
        self.powerAuth = pa
        let url = URL(string: esoUrl)!
        self.activation = WDOActivationService(powerAuth: powerAuth, config: .init(baseUrl: url))
        self.verification = WDOVerificationService(powerAuth: powerAuth, wpnConfig: .init(baseUrl: url))
        self.configuration = WDOConfigurationService(powerAuth: powerAuth, config: .init(baseUrl: url))
    }
    
    @Test func `test config`() async throws {
        for processType in processTypes {
            let config = try await configuration.getConfiguration(processType: processType)
            print("Config for processType: \(processType) retrieved: \(config)")
            #expect(config.documents.groups.count > 0)
        }
    }
}
