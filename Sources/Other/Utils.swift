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

struct JSONCodingKeys: CodingKey {
    var stringValue: String

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int?

    init?(intValue: Int) {
        self.init(stringValue: "\(intValue)")
        self.intValue = intValue
    }
}

// MARK: - helper method to decode generic dictionary from json

extension KeyedDecodingContainer {

    func decode(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any] {
        let container = try self.nestedContainer(keyedBy: JSONCodingKeys.self, forKey: key)
        return try container.decode(type)
    }

    func decodeIfPresent(_ type: [String: Any].Type, forKey key: K) throws -> [String: Any]? {
        guard contains(key) else {
            return nil
        }
        guard try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decode(type, forKey: key)
    }

    func decode(_ type: [Any].Type, forKey key: K) throws -> [Any] {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        return try container.decode(type)
    }

    func decodeIfPresent(_ type: [Any].Type, forKey key: K) throws -> [Any]? {
        guard contains(key) else {
            return nil
        }
        guard try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decode(type, forKey: key)
    }

    func decode(_ type: [String: Any].Type) throws -> [String: Any] {
        var dictionary = [String: Any]()

        for key in allKeys {
            if let boolValue = try? decode(Bool.self, forKey: key) {
                dictionary[key.stringValue] = boolValue
            } else if let stringValue = try? decode(String.self, forKey: key) {
                dictionary[key.stringValue] = stringValue
            } else if let intValue = try? decode(Int.self, forKey: key) {
                dictionary[key.stringValue] = intValue
            } else if let doubleValue = try? decode(Double.self, forKey: key) {
                dictionary[key.stringValue] = doubleValue
            } else if let nestedDictionary = try? decode([String: Any].self, forKey: key) {
                dictionary[key.stringValue] = nestedDictionary
            } else if let nestedArray = try? decode([Any].self, forKey: key) {
                dictionary[key.stringValue] = nestedArray
            }
        }
        return dictionary
    }
}

extension UnkeyedDecodingContainer {

    mutating func decode(_ type: [Any].Type) throws -> [Any] {
        var array: [Any] = []
        while isAtEnd == false {
            // See if the current value in the JSON array is `null` first and prevent infite recursion with nested arrays.
            if try decodeNil() {
                continue
            } else if let value = try? decode(Bool.self) {
                array.append(value)
            } else if let value = try? decode(Double.self) {
                array.append(value)
            } else if let value = try? decode(String.self) {
                array.append(value)
            } else if let nestedDictionary = try? decode([String: Any].self) {
                array.append(nestedDictionary)
            } else if let nestedArray = try? decode(Array<Any>.self) {
                array.append(nestedArray)
            }
        }
        return array
    }

    mutating func decode(_ type: Dictionary<String, Any>.Type) throws -> [String: Any] {

        let nestedContainer = try self.nestedContainer(keyedBy: JSONCodingKeys.self)
        return try nestedContainer.decode(type)
    }
}

// TODO: move this to the networking library
extension OperationQueue {
    func addAsyncOperation(_ completionQueue: DispatchQueue? = nil, _ executionBlock: @escaping WPNAsyncBlockOperation.ExecutionBlock) {
        let op = WPNAsyncBlockOperation(executionBlock)
        op.completionQueue = completionQueue
        addOperation(op)
    }
}

class ISO8601DurationFormatter: Formatter {
    
    private let dateUnitMapping: [Character: Calendar.Component] = ["Y": .year, "M": .month, "W": .weekOfYear, "D": .day]
    private let timeUnitMapping: [Character: Calendar.Component] = ["H": .hour, "M": .minute, "S": .second]
    
    func dateComponents(from string: String) -> DateComponents? {
        var dateComponents: AnyObject?
        if getObjectValue(&dateComponents, for: string, errorDescription: nil) {
            return dateComponents as? DateComponents
        }
        
        return nil
    }
    
    override func string(for obj: Any?) -> String? {
        return nil
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        guard let unitValues = durationUnitValues(for: string) else {
            return false
        }

        var components = DateComponents()
        for (unit, value) in unitValues {
            components.setValue(value, for: unit)
        }
        obj?.pointee = components as AnyObject
        return true
    }
    
    func durationUnitValues(for string: String) -> [(Calendar.Component, Int)]? {
        guard string.hasPrefix("P") else {
            return nil
        }

        let duration = String(string.dropFirst())

        guard let separatorRange = duration.range(of: "T") else {
            return unitValuesWithMapping(for: duration, dateUnitMapping)
        }

        let date = String(duration[..<separatorRange.lowerBound])
        let time = String(duration[separatorRange.upperBound...])

        guard let dateUnits = unitValuesWithMapping(for: date, dateUnitMapping),
              let timeUnits = unitValuesWithMapping(for: time, timeUnitMapping) else {
            return nil
        }

        return dateUnits + timeUnits
    }
    
    func unitValuesWithMapping(for string: String, _ mapping: [Character: Calendar.Component]) -> [(Calendar.Component, Int)]? {
        if string.isEmpty {
            return []
        }

        var components: [(Calendar.Component, Int)] = []

        let identifiersSet = CharacterSet(charactersIn: String(mapping.keys))

        let scanner = Scanner(string: string)
        while !scanner.isAtEnd {
            
            guard let value = scanner.scanInt() else {
                return nil
            }

            guard let identifier = scanner.scanCharacters(from: identifiersSet) else {
                return nil
            }

            let unit = mapping[Character(identifier)]!
            components.append((unit, value))
        }
        return components
    }
}

extension Result {
    
    // Helper methods for easier use instead of switch or if-case
    
    var ok: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    var error: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
    
    var success: Success? {
        if case .success(let success) = self {
            return success
        }
        return nil
    }

    @discardableResult
    func onSuccess(callback: (Success) -> Void) -> Result<Success, Failure> {
        if case .success(let result) = self {
            callback(result)
        }
        return self
    }
    
    @discardableResult
    func onSuccess(callback: () -> Void) -> Result<Success, Failure> {
        if case .success = self {
            callback()
        }
        return self
    }
    
    @discardableResult
    func onError(callback: (Failure) -> Void) -> Result<Success, Failure> {
        if case .failure(let error) = self {
            callback(error)
        }
        return self
    }
    
    @discardableResult
    func onError(callback: () -> Void) -> Result<Success, Failure> {
        if case .failure = self {
            callback()
        }
        return self
    }
}

enum DocumentAction {
    case proceed
    case error
    case wait
}

extension Document {
    var action: DocumentAction {
        switch self.status {
        case .accepted:
            return .proceed
        case .uploadInProgress, .inProgress, .verificationPending, .verificationInProgress:
            return .wait
        case .rejected, .failed:
            return .error
        }
    }
}
