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

import UIKit

/// Describes the state of documents that need to be uploaded to the server.
public class WDOVerificationScanProcess {

    /// All documents that need to be scanned.
    public let documents: [WDOScannedDocument]

    /// Which document should be scanned next. `nil` when all documents are uploaded and accepted.
    public var nextDocumentToScan: WDOScannedDocument? {
        documents.first { $0.uploadState != .accepted }
    }

    // internal init
    internal init(types: [WDODocumentType]) {
        self.documents = types.map { .init($0) }
    }

    // fileprivate init for restoring from v2 cache with pre-populated documents
    fileprivate init(restoredDocuments: [WDOScannedDocument]) {
        self.documents = restoredDocuments
    }
}

/// Document that needs to be scanned during process.
public class WDOScannedDocument {

    /// Type of the document.
    public let type: WDODocumentType

    /// Upload state.
    public var uploadState: UploadState {
        // if there are no sides, consider the document not uploaded
        guard !sides.isEmpty else {
            return .notUploaded
        }
        // if any side is rejected, consider whole document rejected
        return sides.contains { $0.uploadState == .rejected } ? .rejected : .accepted
    }

    /// Sides of the document that were uploaded on the server.
    public private(set) var sides: [Side]

    fileprivate init(_ type: WDODocumentType, sides: [Side] = []) {
        self.type = type
        self.sides = sides
    }

    fileprivate func processServerData(documents: [Document]) {
        sides = documents.map {
            .init(
                type: .from(apiType: $0.side), serverId: $0.id,
                country: $0.country,
                uploadState: $0.errors?.isEmpty == false ? .rejected : .accepted)
        }
    }

    /// State of the document on the server.
    public enum UploadState {

        /// The document was not uploaded yet.
        case notUploaded

        /// The document was accepted by the server.
        case accepted

        /// The document was rejected and needs to be re-uploaded.
        case rejected
    }

    /// Side of the uploaded document.
    public struct Side {

        /// Type of the side.
        public let type: WDODocumentSide

        /// ID on the server. Use this ID in case of an reupload
        public let serverId: String

        /// Document country as an ISO 3166-1 alpha-3 code (e.g. "CZE"). Optional.
        public let country: String?

        /// Upload state of the document
        public let uploadState: UploadState
    }
}

// MARK: - Internal/Private

extension WDOVerificationScanProcess {

    convenience init?(cacheData: String) {
        // Try v2 JSON format first
        if let jsonData = cacheData.data(using: .utf8),
            let cache = try? JSONDecoder().decode(CacheV2.self, from: jsonData),
            cache.v == 2 {
            let docs = cache.documents.map { cachedDoc in
                WDOScannedDocument(
                    cachedDoc.type,
                    sides: cachedDoc.sides.map { cachedSide in
                        WDOScannedDocument.Side(
                            type: cachedSide.side == .front ? .front : .back,
                            serverId: cachedSide.serverId,
                            country: cachedSide.country,
                            uploadState: cachedSide.uploadState == .accepted ? .accepted : .rejected
                        )
                    }
                )
            }
            self.init(restoredDocuments: docs)
            return
        }

        // Fall back to v1 format
        let split = cacheData.split(separator: ":").map { String($0) }
        guard split.count == 2 else {
            D.error("Cannot create scan process from cache - unknown cache format")
            return nil
        }

        guard let version = CacheVersion(rawValue: split[0]), version == .v1 else {
            D.error("Cannot create scan process from cache - unknown cache version")
            return nil
        }

        let types = split[1].split(separator: ",").compactMap(String.init)
        self.init(types: types)
    }

    func feed(_ serverData: [Document]) {
        for group in Dictionary(grouping: serverData, by: { $0.type }) {
            if let document = documents.first(where: { $0.type == group.key }) {
                document.processServerData(documents: group.value)
            }
        }
    }

    private enum CacheVersion: String {
        case v1
    }

    enum CacheError: Error {
        case encodingFailed
    }

    // Cache v2 format: JSON with document types, sides, and server IDs.
    // Allows auto-assigning originalDocumentId on resubmit.
    private struct CacheV2: Codable {
        let v: Int
        let documents: [CachedDocument]

        struct CachedDocument: Codable {
            let type: String
            let sides: [CachedSide]
        }

        struct CachedSide: Codable {
            let side: Side
            let serverId: String
            let country: String?
            let uploadState: UploadState

            enum Side: String, Codable {
                case front
                case back
            }

            enum UploadState: String, Codable {
                case accepted
                case rejected
            }
        }
    }

    func dataForCache() throws -> String {
        let cache = CacheV2(
            v: 2,
            documents: documents.map { doc in
                CacheV2.CachedDocument(
                    type: doc.type,
                    sides: doc.sides.map { side in
                        CacheV2.CachedSide(
                            side: side.type == .front ? .front : .back,
                            serverId: side.serverId,
                            country: side.country,
                            uploadState: side.uploadState == .accepted ? .accepted : .rejected
                        )
                    }
                )
            }
        )
        let data = try JSONEncoder().encode(cache)
        guard let string = String(data: data, encoding: .utf8) else {
            throw WDOVerificationScanProcess.CacheError.encodingFailed
        }
        return string
    }
}
