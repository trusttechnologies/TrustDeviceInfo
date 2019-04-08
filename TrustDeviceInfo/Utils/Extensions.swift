//
//  Extensions.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 12/26/18.
//  Copyright © 2018 Jumpitt Labs. All rights reserved.
//

// MARK: Extension Bundle
extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

// MARK: - App Strings
extension String {
    static let appLocale = "es_CL"
    static let yyyyMMddHHmmss = "yyyy-MM-dd HH:mm:ss"
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
