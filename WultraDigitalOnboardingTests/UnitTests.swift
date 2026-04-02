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

import Testing
@testable import WultraDigitalOnboarding

struct UnitTests {

    @Test
    func `scan process preserves server data through cache serialization`() throws {
        let process = WDOVerificationScanProcess(types: ["ID_CARD", "PASSPORT"])

        // Feed server data: ID_CARD with front (accepted) + back (rejected), PASSPORT with front (accepted)
        process.feed([
            Document(filename: "id_front.jpg", id: "srv-1", type: "ID_CARD", side: .front, status: .accepted, errors: nil),
            Document(filename: "id_back.jpg", id: "srv-2", type: "ID_CARD", side: .back, status: .rejected, errors: ["blur"]),
            Document(filename: "pp_front.jpg", id: "srv-3", type: "PASSPORT", side: .front, status: .accepted, errors: nil)
        ])

        // Serialize to v2 cache and deserialize
        let restored = try #require(WDOVerificationScanProcess(cacheData: try process.dataForCache()))

        // ID_CARD — two sides with correct server IDs and upload states
        let idCard = try #require(restored.documents.first { $0.type == "ID_CARD" })
        #expect(idCard.sides.count == 2)
        let idFront = try #require(idCard.sides.first { $0.type == .front })
        #expect(idFront.serverId == "srv-1")
        #expect(idFront.uploadState == .accepted)
        let idBack = try #require(idCard.sides.first { $0.type == .back })
        #expect(idBack.serverId == "srv-2")
        #expect(idBack.uploadState == .rejected)

        // PASSPORT — one side
        let passport = try #require(restored.documents.first { $0.type == "PASSPORT" })
        #expect(passport.sides.count == 1)
        let ppFront = try #require(passport.sides.first)
        #expect(ppFront.serverId == "srv-3")
        #expect(ppFront.uploadState == .accepted)
    }

    @Test
    func `v1 cache migrates to v2`() throws {
        let v1Cache = "v1:ID_CARD,PASSPORT"

        // v1 should parse correctly (no sides)
        let process = try #require(WDOVerificationScanProcess(cacheData: v1Cache))
        #expect(process.documents.count == 2)
        #expect(process.documents[0].type == "ID_CARD")
        #expect(process.documents[1].type == "PASSPORT")
        #expect(process.documents[0].sides.isEmpty)
        #expect(process.documents[1].sides.isEmpty)

        // re-encoding should produce v2 JSON
        let v2Cache = try process.dataForCache()
        #expect(v2Cache.contains("\"v\":2"))
        #expect(v2Cache.contains("ID_CARD"))
        #expect(v2Cache.contains("PASSPORT"))

        // v2 cache should round-trip correctly
        let restored = try #require(WDOVerificationScanProcess(cacheData: v2Cache))
        #expect(restored.documents.count == 2)
        #expect(restored.documents[0].type == "ID_CARD")
        #expect(restored.documents[1].type == "PASSPORT")
        #expect(restored.documents[0].sides.isEmpty)
        #expect(restored.documents[1].sides.isEmpty)
    }
}
