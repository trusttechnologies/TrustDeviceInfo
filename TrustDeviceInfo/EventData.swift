//
//  EventData.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 12/26/18.
//  Copyright © 2018 Jumpitt Labs. All rights reserved.
//

import Alamofire
import DeviceKit

// MARK: - Enum TransactionType
public enum TransactionType: String {
    case sign = "Firma"
    case deny = "Rechaza"
}

// MARK: - Enum AuthMethod
public enum AuthMethod: String {
    case advancedElectronicSignature = "Firma Electronica Avanzada"
    case touchID = "Touch ID"
    case faceID = "Face ID"
}

// MARK: - Struct EventData
public struct EventData {
    
    private let device = Device()
    
    var transactionType: TransactionType?
    var authMethod: AuthMethod?
    var latitude: String?
    var longitude: String?
    var timestamp: String?
    
    public var asParameters: Parameters {
        return [
            "source": [
                "trustid": TrustDeviceInfo.shared.getTrustID(),
                "app_name": Bundle.main.displayName,
                "bundle_id": Bundle.main.bundleIdentifier,
                "system_name": device.systemName,
                "system_version": device.systemVersion
            ],
            "transaction": [
                "operation": transactionType?.rawValue ?? "",
                "method": authMethod?.rawValue ?? "",
                "timestamp": timestamp ?? ""
            ],
            "geo": [
                "lat": latitude ?? "",
                "long": longitude ?? ""
            ]
        ]
    }
    
    public init(transactionType: TransactionType, authMethod: AuthMethod, latitude: String, longitude: String, timestamp: String) {
        self.transactionType = transactionType
        self.authMethod = authMethod
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
}
