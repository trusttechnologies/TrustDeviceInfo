//
//  EventData.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 12/26/18.
//  Copyright © 2018 Jumpitt Labs. All rights reserved.
//

/*import Alamofire
import DeviceKit

// MARK: - Enum TransactionType
public enum OperationType: String {
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
    
    private let device = Device.current
    
    var operationType: OperationType?
    var authMethod: AuthMethod?
    var latitude: String?
    var longitude: String?
    var timestamp: String?
    
    var auditType: String?
    var connectionType: String?
    var connectionName: String?
    var transactionType: String?
    var transactionResult: String?
    
    var trustIDManager: TrustIDManagerProtocol {
        return TrustIDManager()
    }
    
    public var asParameters: Parameters {
        return [
            "type_audit": auditType ?? .empty,
            "platform": "iOS",
            "application": Bundle.main.displayName ?? .empty,
            "source": [
                "trust_id": trustIDManager.getTrustID(),
                "app_name": Bundle.main.displayName,
                "bundle_id": Bundle.main.bundleIdentifier,
                "os": device.systemName,
                "os_version": device.systemVersion,
                "device_name": Sysctl.model,
                "latGeo": latitude ?? .empty,
                "lonGeo": longitude ?? .empty,
                "connection_type": connectionType,
                "connection_name": connectionName,
                "version_app": "\(Bundle.main.versionNumber ?? "1").\(Bundle.main.buildNumber ?? "1")"
            ],
            "transaction": [
                "type": transactionType ?? .empty,
                "result": transactionResult ?? .empty,
                "timestamp": timestamp ?? .empty,
                "method": authMethod?.rawValue ?? .empty,
                "operation": operationType?.rawValue ?? .empty
            ]
        ]
    }
    
    public init(operationType: OperationType, authMethod: AuthMethod, latitude: String, longitude: String, timestamp: String) {
        self.operationType = operationType
        self.authMethod = authMethod
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
}*/
