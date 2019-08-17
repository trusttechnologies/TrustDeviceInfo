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
    static let zero = "0"
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
    
    var appVersion: String {
        return "\(versionNumber ?? .zero).\(buildNumber ?? .zero)"
    }
}

// MARK: - CustomStringConvertible
extension CustomStringConvertible {
    public var description: String {
        var description: String = .empty
        let selfMirror = Mirror(reflecting: self)
        
        for child in selfMirror.children {
            if let propertyName = child.label {
                description += "\(propertyName): \(child.value)\n"
            }
        }
        
        return description
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

// MARK: - Parameterizable
protocol Parameterizable {
    var asParameters: Parameters {get}
}
