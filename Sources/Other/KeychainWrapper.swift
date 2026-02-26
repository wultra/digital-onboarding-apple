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

class KeychainWrapper {
    
    /// Default keychain wrapper access
    static let standard = KeychainWrapper()
    
    /// ServiceName is used for the kSecAttrService property to uniquely identify this keychain accessor. If no service name is specified, KeychainWrapper will default to using the bundleIdentifier.
    var serviceName: String
    
    /// AccessGroup is used for the kSecAttrAccessGroup property to identify which Keychain Access Group this entry belongs to. This allows you to use the KeychainWrapper with shared keychain access between different applications.
    private(set) var accessGroup: String?
    
    private static let defaultServiceName = "wdokw"

    private convenience init() {
        self.init(serviceName: KeychainWrapper.defaultServiceName)
    }
    
    /// Create a custom instance of KeychainWrapper with a custom Service Name and optional custom access group.
    ///
    /// - parameter serviceName: The ServiceName for this instance. Used to uniquely identify all keys stored using this keychain wrapper instance.
    /// - parameter accessGroup: Optional unique AccessGroup for this instance. Use a matching AccessGroup between applications to allow shared keychain access.
    init(serviceName: String, accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    // MARK: - Public Methods
    
    /// Checks if keychain data exists for a specified key.
    ///
    /// - parameter forKey: The key to check for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: True if a value exists for the key. False otherwise.
    func hasValue(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        return data(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable) != nil
    }
    
    func accessibilityOfKey(_ key: String) -> KeychainItemAccessibility? {
        var keychainQueryDictionary = setupKeychainQueryDictionary(forKey: key)

        // Remove accessibility attribute
        keychainQueryDictionary.removeValue(forKey: SecAttrAccessible)
        
        // Limit search results to one
        keychainQueryDictionary[SecMatchLimit] = kSecMatchLimitOne

        // Specify we want SecAttrAccessible returned
        keychainQueryDictionary[SecReturnAttributes] = kCFBooleanTrue

        // Search
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)

        guard status == noErr, let resultsDictionary = result as? [String: AnyObject], let accessibilityAttrValue = resultsDictionary[SecAttrAccessible] as? String else {
            return nil
        }
    
        return KeychainItemAccessibility.accessibilityForAttributeValue(accessibilityAttrValue as CFString)
    }

    /// Get the keys of all keychain entries matching the current ServiceName and AccessGroup if one is set.
    func allKeys() -> Set<String> {
        var keychainQueryDictionary: [String: Any] = [
            SecClass: kSecClassGenericPassword,
            SecAttrService: serviceName,
            SecReturnAttributes: kCFBooleanTrue!,
            SecMatchLimit: kSecMatchLimitAll
        ]

        if let accessGroup = self.accessGroup {
            keychainQueryDictionary[SecAttrAccessGroup] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)

        guard status == errSecSuccess else { return [] }

        var keys = Set<String>()
        if let results = result as? [[AnyHashable: Any]] {
            for attributes in results {
                if let accountData = attributes[SecAttrAccount] as? Data,
                    let key = String(data: accountData, encoding: String.Encoding.utf8) {
                    keys.insert(key)
                } else if let accountData = attributes[kSecAttrAccount] as? Data,
                    let key = String(data: accountData, encoding: String.Encoding.utf8) {
                    keys.insert(key)
                }
            }
        }
        return keys
    }
    
    // MARK: Public Getters
    
    func integer(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Int? {
        guard let numberValue: NSNumber = object(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable) else {
            return nil
        }
        
        return numberValue.intValue
    }
    
    func float(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Float? {
        guard let numberValue: NSNumber = object(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable) else {
            return nil
        }
        
        return numberValue.floatValue
    }
    
    func double(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Double? {
        guard let numberValue: NSNumber = object(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable) else {
            return nil
        }
        
        return numberValue.doubleValue
    }
    
    func bool(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool? {
        guard let numberValue: NSNumber = object(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable) else {
            return nil
        }
        
        return numberValue.boolValue
    }
    
    /// Returns a string value for a specified key.
    ///
    /// - parameter forKey: The key to lookup data for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: The String associated with the key if it exists. If no data exists, or the data found cannot be encoded as a string, returns nil.
    func string(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> String? {
        guard let keychainData = data(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable) else {
            return nil
        }
        
        return String(data: keychainData, encoding: String.Encoding.utf8) as String?
    }
    
    /// Returns an object that conforms to NSCoding for a specified key.
    ///
    /// - parameter forKey: The key to lookup data for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: The decoded object associated with the key if it exists. If no data exists, or the data found cannot be decoded, returns nil.
    func object<T: NSObject & NSCoding>(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> T? {
        guard let keychainData = data(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable) else {
            return nil
        }
        
        return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [T.self, NSNumber.self, NSString.self, NSArray.self, NSDictionary.self], from: keychainData) as? T
    }

    /// Returns a Data object for a specified key.
    ///
    /// - parameter forKey: The key to lookup data for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: The Data object associated with the key if it exists. If no data exists, returns nil.
    func data(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Data? {
        var keychainQueryDictionary = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
        
        // Limit search results to one
        keychainQueryDictionary[SecMatchLimit] = kSecMatchLimitOne
        
        // Specify we want Data/CFData returned
        keychainQueryDictionary[SecReturnData] = kCFBooleanTrue
        
        // Search
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)
        
        return status == noErr ? result as? Data : nil
    }
    
    /// Returns a persistent data reference object for a specified key.
    ///
    /// - parameter forKey: The key to lookup data for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: The persistent data reference object associated with the key if it exists. If no data exists, returns nil.
    func dataRef(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Data? {
        var keychainQueryDictionary = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
        
        // Limit search results to one
        keychainQueryDictionary[SecMatchLimit] = kSecMatchLimitOne
        
        // Specify we want persistent Data/CFData reference returned
        keychainQueryDictionary[SecReturnPersistentRef] = kCFBooleanTrue
        
        // Search
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)
        
        return status == noErr ? result as? Data : nil
    }
    
    // MARK: Public Setters
    
    @discardableResult func set(_ value: Int, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        return set(NSNumber(value: value), forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
    }
    
    @discardableResult func set(_ value: Float, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        return set(NSNumber(value: value), forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
    }
    
    @discardableResult func set(_ value: Double, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        return set(NSNumber(value: value), forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
    }
    
    @discardableResult func set(_ value: Bool, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        return set(NSNumber(value: value), forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
    }

    /// Save a String value to the keychain associated with a specified key. If a String value already exists for the given key, the string will be overwritten with the new value.
    ///
    /// - parameter value: The String value to save.
    /// - parameter forKey: The key to save the String under.
    /// - parameter withAccessibility: Optional accessibility to use when setting the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: True if the save was successful, false otherwise.
    @discardableResult func set(_ value: String, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        if let data = value.data(using: .utf8) {
            return set(data, forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
        } else {
            return false
        }
    }

    /// Save an NSCoding compliant object to the keychain associated with a specified key. If an object already exists for the given key, the object will be overwritten with the new value.
    ///
    /// - parameter value: The NSCoding compliant object to save.
    /// - parameter forKey: The key to save the object under.
    /// - parameter withAccessibility: Optional accessibility to use when setting the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: True if the save was successful, false otherwise.
    @discardableResult func set(_ value: NSCoding, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false) else {
            return false
        }
        
        return set(data, forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
    }

    /// Save a Data object to the keychain associated with a specified key. If data already exists for the given key, the data will be overwritten with the new value.
    ///
    /// - parameter value: The Data object to save.
    /// - parameter forKey: The key to save the object under.
    /// - parameter withAccessibility: Optional accessibility to use when setting the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: True if the save was successful, false otherwise.
    @discardableResult func set(_ value: Data, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        var keychainQueryDictionary: [String: Any] = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
        
        keychainQueryDictionary[SecValueData] = value
        
        if let accessibility = accessibility {
            keychainQueryDictionary[SecAttrAccessible] = accessibility.keychainAttrValue
        } else {
            // Assign default protection - Protect the keychain entry so it's only valid when the device is unlocked
            keychainQueryDictionary[SecAttrAccessible] = KeychainItemAccessibility.whenUnlocked.keychainAttrValue
        }
        
        let status: OSStatus = SecItemAdd(keychainQueryDictionary as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else if status == errSecDuplicateItem {
            return update(value, forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
        } else {
            D.debug("KeychainWrapper: Error saving to keychain: \(status)")
            return false
        }
    }
    
    /// Remove an object associated with a specified key. If re-using a key but with a different accessibility, first remove the previous key value using removeObjectForKey(:withAccessibility) using the same accessibilty it was saved with.
    ///
    /// - parameter forKey: The key value to remove data for.
    /// - parameter withAccessibility: Optional accessibility level to use when looking up the keychain item.
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: True if successful, false otherwise.
    @discardableResult func removeObject(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        let keychainQueryDictionary: [String: Any] = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)

        // Delete
        let status: OSStatus = SecItemDelete(keychainQueryDictionary as CFDictionary)

        if status == errSecSuccess {
            return true
        } else {
            return false
        }
    }

    /// Remove all keychain data added through KeychainWrapper. This will only delete items matching the currnt ServiceName and AccessGroup if one is set.
    @discardableResult func removeAllKeys() -> Bool {
        // Setup dictionary to access keychain and specify we are using a generic password (rather than a certificate, internet password, etc)
        var keychainQueryDictionary: [String: Any] = [SecClass: kSecClassGenericPassword]
        
        // Uniquely identify this keychain accessor
        keychainQueryDictionary[SecAttrService] = serviceName
        
        // Set the keychain access group if defined
        if let accessGroup = self.accessGroup {
            keychainQueryDictionary[SecAttrAccessGroup] = accessGroup
        }
        
        let status: OSStatus = SecItemDelete(keychainQueryDictionary as CFDictionary)
        
        if status == errSecSuccess {
            return true
        } else {
            return false
        }
    }
    
    /// Remove all keychain data, including data not added through keychain wrapper.
    ///
    /// - Warning: This may remove custom keychain entries you did not add via SwiftKeychainWrapper.
    ///
    class func wipeKeychain() {
        deleteKeychainSecClass(kSecClassGenericPassword) // Generic password items
        deleteKeychainSecClass(kSecClassInternetPassword) // Internet password items
        deleteKeychainSecClass(kSecClassCertificate) // Certificate items
        deleteKeychainSecClass(kSecClassKey) // Cryptographic key items
        deleteKeychainSecClass(kSecClassIdentity) // Identity items
    }

    // MARK: - Private Methods
    
    /// Remove all items for a given Keychain Item Class
    ///
    ///
    @discardableResult private class func deleteKeychainSecClass(_ secClass: AnyObject) -> Bool {
        let query = [SecClass: secClass]
        let status: OSStatus = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            return true
        } else {
            return false
        }
    }
    
    /// Update existing data associated with a specified key name. The existing data will be overwritten by the new data.
    private func update(_ value: Data, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> Bool {
        var keychainQueryDictionary: [String: Any] = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility, isSynchronizable: isSynchronizable)
        let updateDictionary = [SecValueData: value]
        
        // on update, only set accessibility if passed in
        if let accessibility = accessibility {
            keychainQueryDictionary[SecAttrAccessible] = accessibility.keychainAttrValue
        }
        
        // Update
        let status: OSStatus = SecItemUpdate(keychainQueryDictionary as CFDictionary, updateDictionary as CFDictionary)

        if status == errSecSuccess {
            return true
        } else {
            return false
        }
    }

    /// Setup the keychain query dictionary used to access the keychain on iOS for a specified key name. Takes into account the Service Name and Access Group if one is set.
    ///
    /// - parameter forKey: The key this query is for
    /// - parameter withAccessibility: Optional accessibility to use when setting the keychain item. If none is provided, will default to .WhenUnlocked
    /// - parameter isSynchronizable: A bool that describes if the item should be synchronizable, to be synched with the iCloud. If none is provided, will default to false
    /// - returns: A dictionary with all the needed properties setup to access the keychain on iOS
    private func setupKeychainQueryDictionary(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil, isSynchronizable: Bool = false) -> [String: Any] {
        // Setup default access as generic password (rather than a certificate, internet password, etc)
        var keychainQueryDictionary: [String: Any] = [SecClass: kSecClassGenericPassword]
        
        // Uniquely identify this keychain accessor
        keychainQueryDictionary[SecAttrService] = serviceName
        
        // Only set accessibiilty if its passed in, we don't want to default it here in case the user didn't want it set
        if let accessibility = accessibility {
            keychainQueryDictionary[SecAttrAccessible] = accessibility.keychainAttrValue
        }
        
        // Set the keychain access group if defined
        if let accessGroup = self.accessGroup {
            keychainQueryDictionary[SecAttrAccessGroup] = accessGroup
        }
        
        // Uniquely identify the account who will be accessing the keychain
        let encodedIdentifier: Data? = key.data(using: String.Encoding.utf8)
        
        keychainQueryDictionary[SecAttrGeneric] = encodedIdentifier
        
        keychainQueryDictionary[SecAttrAccount] = encodedIdentifier
        
        keychainQueryDictionary[SecAttrSynchronizable] = isSynchronizable ? kCFBooleanTrue : kCFBooleanFalse
        
        return keychainQueryDictionary
    }
}

protocol KeychainAttrRepresentable {
    var keychainAttrValue: CFString { get }
}

// MARK: - KeychainItemAccessibility
enum KeychainItemAccessibility {
    /**
     The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
     
     After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute migrate to a new device when using encrypted backups.
    */
    case afterFirstUnlock
    
    /**
     The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
     
     After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
     */
    case afterFirstUnlockThisDeviceOnly
    
    /**
     The data in the keychain can only be accessed when the device is unlocked. Only available if a passcode is set on the device.
     
     This is recommended for items that only need to be accessible while the application is in the foreground. Items with this attribute never migrate to a new device. After a backup is restored to a new device, these items are missing. No items can be stored in this class on devices without a passcode. Disabling the device passcode causes all items in this class to be deleted.
     */
    case whenPasscodeSetThisDeviceOnly
    
    /**
     The data in the keychain item can be accessed only while the device is unlocked by the user.
     
     This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute migrate to a new device when using encrypted backups.
     
     This is the default value for keychain items added without explicitly setting an accessibility constant.
     */
    case whenUnlocked
    
    /**
     The data in the keychain item can be accessed only while the device is unlocked by the user.
     
     This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
     */
    case whenUnlockedThisDeviceOnly
    
    static func accessibilityForAttributeValue(_ keychainAttrValue: CFString) -> KeychainItemAccessibility? {
        return keychainItemAccessibilityLookup.first { (_, v) in v == keychainAttrValue }?.key
    }
}

private let keychainItemAccessibilityLookup: [KeychainItemAccessibility: CFString] = {
    var lookup: [KeychainItemAccessibility: CFString] = [
        .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlock,
        .afterFirstUnlockThisDeviceOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        .whenPasscodeSetThisDeviceOnly: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .whenUnlocked: kSecAttrAccessibleWhenUnlocked,
        .whenUnlockedThisDeviceOnly: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]

    return lookup
}()

extension KeychainItemAccessibility: KeychainAttrRepresentable {
    var keychainAttrValue: CFString {
        return keychainItemAccessibilityLookup[self]!
    }
}

// shortcuts to constants

private let SecMatchLimit = kSecMatchLimit as String
private let SecReturnData = kSecReturnData as String
private let SecReturnPersistentRef = kSecReturnPersistentRef as String
private let SecValueData = kSecValueData as String
private let SecAttrAccessible = kSecAttrAccessible as String
private let SecClass = kSecClass as String
private let SecAttrService = kSecAttrService as String
private let SecAttrGeneric = kSecAttrGeneric as String
private let SecAttrAccount = kSecAttrAccount as String
private let SecAttrAccessGroup = kSecAttrAccessGroup as String
private let SecReturnAttributes = kSecReturnAttributes as String
private let SecAttrSynchronizable = kSecAttrSynchronizable as String
