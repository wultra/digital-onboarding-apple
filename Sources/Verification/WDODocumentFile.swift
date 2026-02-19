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

/// Image of a document that can be sent to the backend for Identity Verification.
public class WDODocumentFile {
    /// Raw data to upload. Make sure that the data aren't too big, hundreds of kbs should be enough.
    public var data: Data
    /// Image signature.
    ///
    /// Optional, use only when the scan SDK supports this.
    public var dataSignature: String?
    /// Type of the document.
    /// Expected values like: `ID_CARD`, `PASSPORT`, `DRIVING_LICENSE`.
    /// All possible values can be found at backend implementation:
    /// https://github.com/wultra/enrollment-server/blob/develop/enrollment-server-onboarding-domain-model/src/main/java/com/wultra/app/enrollmentserver/model/enumeration/DocumentType.java
    /// Expected/possible values can be obtained from `WDOConfigurationService.getConfiguration()`.
    public let type: WDODocumentType
    /// Side of the document (`front` if the document is one-sided or only one side is expected).
    public let side: WDODocumentSide
    /// For image reuploading when the previous file of the same document was rejected.
    ///
    /// Without specifying this value, the document side won't be overwritten.
    public let originalDocumentId: String?
    
    /// Image of a document that can be sent to the backend for Identity Verification.
    ///
    /// - Parameters:
    ///   - scannedDocument: Document to upload.
    ///   - data: Raw image data.  Make sure that the data aren't too big, hundreds of kbs should be enough.
    ///   - side: The side of the document that the image captures.
    ///   - dataSignature: Signature of the image data. Optional, use only when the scan SDK supports this. `nil` by default.
    public convenience init(scannedDocument: WDOScannedDocument, data: Data, side: WDODocumentSide, dataSignature: String? = nil) {
        let originalDocumentId = scannedDocument.sides.first { $0.type == side }?.serverId
        self.init(data: data, dataSignature: dataSignature, type: scannedDocument.type, side: side, originalDocumentId: originalDocumentId)
    }
    
    /// Image of a document that can be sent to the backend for Identity Verification.
    ///
    /// - Parameters:
    ///   - data: Raw image data.  Make sure that the data aren't too big, hundreds of kbs should be enough.
    ///   - type: The type of the document.
    ///   - side: The side of the document the the image captures
    ///   - originalDocumentId: Original document ID In case of a reupload. If you've previously uploaded this type and side and won't specify the previous ID, the image won't be overwritten.
    ///   - dataSignature: Signature of the image data. Optional, use only when the scan SDK supports this. `nil` by default.
    public convenience init(data: Data, type: WDODocumentType, side: WDODocumentSide, originalDocumentId: String?, dataSignature: String? = nil) {
        self.init(data: data, dataSignature: dataSignature, type: type, side: side, originalDocumentId: originalDocumentId)
    }
    
    // internal init
    init(data: Data, dataSignature: String? = nil, type: WDODocumentType, side: WDODocumentSide, originalDocumentId: String?) {
        self.data = data
        self.dataSignature = dataSignature
        self.type = type
        self.side = side
        self.originalDocumentId = originalDocumentId
    }
}

public extension WDOScannedDocument {
    
    /// Creates an image that can be sent to the backend for Identity Verification.
    ///
    /// - Parameters:
    ///   - side: The side of the document that the image captures.
    ///   - data: Raw image data.  Make sure that the data aren't too big, hundreds of kbs should be enough.
    ///   - dataSignature: Signature of the image data. Optional, use only when the scan SDK supports this. `nil` by default.
    /// - Returns: A document file for upload.
    func createFileForUpload(side: WDODocumentSide, data: Data, dataSignature: String? = nil) -> WDODocumentFile {
        return WDODocumentFile(scannedDocument: self, data: data, side: side, dataSignature: dataSignature)
    }
}

/// Type of the document.
public typealias WDODocumentType = String

/// Side of the document
public enum WDODocumentSide: String {
    /// Front side of a document. Usually the one with the picture.
    ///
    /// When a document has more than one side but only one side is used (for example passport), then such side is considered to be front.
    case front
    /// Back side of a document
    case back
}
