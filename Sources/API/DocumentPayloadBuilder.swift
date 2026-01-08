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
import UIKit

/// Request builder of the `submitDocuments` API call.
class DocumentPayloadBuilder {
    
    /// Builds the request for the `submitDocuments` call.
    /// - Parameters:
    ///   - processId: ID of the process
    ///   - files: Documents to upload
    /// - Returns: Request
    /// - Throws: Various errors during the document processing.
    static func build(processId: String, files: [WDODocumentFile]) throws -> DocumentSubmitRequest {
        DocumentSubmitRequest(
            processId: processId,
            resubmit: files.contains { $0.originalDocumentId != nil },
            documents: files.map { $0.toSubmitFile() }
        )
    }
}

extension WDODocumentFile {
    
    /// We expect only one document per type(+side) in the final payload
    /// so the name is result of such setup.
    fileprivate var filename: String { "\(type.rawValue.lowercased())_\(side.rawValue.lowercased()).jpg" }
    
    fileprivate func toSubmitFile() -> DocumentSubmitFile {
        DocumentSubmitFile(
            filename: filename,
            type: type.apiType,
            side: side.apiType,
            originalDocumentId: originalDocumentId,
            data: data.base64EncodedString(options: [])
        )
    }
}

extension WDODocumentType {
    var apiType: DocumentSubmitFileType {
        switch self {
        case .idCard: return .idCard
        case .passport: return .passport
        case .driversLicense: return .driversLicense
        }
    }
}

extension WDODocumentSide {
    var apiType: DocumentSubmitFileSide {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
    
    static func from(apiType: DocumentSubmitFileSide) -> Self {
        switch apiType {
        case .front: return .front
        case .back: return .back
        }
    }
}
