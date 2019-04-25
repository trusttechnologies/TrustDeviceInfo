//
//  Extensions.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 12/26/18.
//  Copyright © 2018 Jumpitt Labs. All rights reserved.
//

import Alamofire

// MARK: -  Typealias
typealias CompletionHandler = (()->Void)?
typealias SuccessHandler<T> = ((T)-> Void)?

// MARK: - App Strings
extension String {
    static let empty = ""
    static let appLocale = "es_CL"
    static let yyyyMMddHHmmss = "yyyy-MM-dd HH:mm:ss"
}

// MARK: Extension Bundle
extension Bundle {
    var versionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }

    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

// MARK: - Extension Date
extension Date {
    func toString(with format: String) -> String {
        let dateFormatter = DateFormatter()
        
        dateFormatter.locale = Locale(identifier: .appLocale)
        dateFormatter.dateFormat = format
        
        return dateFormatter.string(from: self)
    }
}

// MARK: - KeyNamespaceable
protocol KeyNamespaceable {}

extension KeyNamespaceable {
    static func namespace<T>(_ key: T) -> String where T: RawRepresentable {
        return "\(Self.self).\(key.rawValue)"
    }
}

// MARK: - StringKeychainWrapperable
protocol StringKeychainWrapperable: KeyNamespaceable {
    associatedtype StringKeys: RawRepresentable
}

extension StringKeychainWrapperable where StringKeys.RawValue == String {
    static func set(_ value: String, forKey key: StringKeys) {
        let key = namespace(key)
        KeychainWrapper.standard.set(value, forKey: key)
    }
    
    static func string(forKey key: StringKeys, keychainItemAccessibility: KeychainItemAccessibility? = nil) -> String? {
        let key = namespace(key)
        return KeychainWrapper.standard.string(forKey: key, withAccessibility: keychainItemAccessibility)
    }
    
    static func remove(forKey key: StringKeys) {
        let key = namespace(key)
        KeychainWrapper.standard.removeObject(forKey: key)
    }
}

// MARK: - Extension KeychainWrapper
extension KeychainWrapper {
    struct ClientCredentials: StringKeychainWrapperable {
        enum StringKeys: String {
            case accessToken
            case tokenType
        }
    }
}

// MARK: - Parameterizable
protocol Parameterizable {
    var asParameters: Parameters {get}
}
