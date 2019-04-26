//
//  Parameters.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/22/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

import Alamofire
import CoreTelephony
import DeviceKit

// MARK: - IdentityInfoDataSource
public protocol IdentityInfoDataSource {
    var dni: String {get}
    var name: String? {get}
    var lastname: String? {get}
    var email: String? {get}
    var phone: String? {get}
}

// MARK: - ClientCredentialsParameters
struct ClientCredentialsParameters: Parameterizable {
    var clientID: String?
    var clientSecret: String?
    
    let grantType = "client_credentials"
    
    public var asParameters: Parameters {
        guard
            let clientID = clientID,
            let clientSecret = clientSecret else {
                return [:]
        }
        
        return [
            "client_id": clientID,
            "client_secret": clientSecret,
            "grant_type": grantType
        ]
    }
}

// MARK: - AppStateParameters
struct AppStateParameters: Parameterizable {
    var dni: String?
    var bundleID: String?
    
    private var trustID: String? {
        return trustIDManager.getTrustID()
    }

    private var trustIDManager: TrustIDManagerProtocol {
        return TrustIDManager()
    }
    
    public var asParameters: Parameters {
        guard
            let trustID = trustID,
            let dni = dni,
            let bundleID = bundleID else {
                return [:]
        }
        
        return [
            "trust_id": trustID,
            "dni": dni,
            "bundle_id": bundleID
        ]
    }
}

// MARK: - CreateAuditParameters
public struct CreateAuditParameters: Parameterizable {
    public var auditType: String?
    public var platform: String?
    public var application: String?
    public var source: Source?
    public var transaction: Transaction?
    
    public var asParameters: Parameters {
        guard
            let auditType = auditType,
            let platform = platform,
            let application = application,
            let source = source,
            let transaction = transaction else {
                return [:]
        }

        return [
            "type_audit": auditType,
            "platform": platform,
            "application": application,
            "source": source.asParameters,
            "transaction": transaction.asParameters
        ]
    }
}

public struct Source: Parameterizable {
    private var trustID: String? {
        return trustIDManager.getTrustID()
    }

    private var trustIDManager: TrustIDManagerProtocol {
        return TrustIDManager()
    }

    public var appName: String?
    public var bundleID: String?
    public var latitude: String?
    public var longitude: String?
    public var connectionType: String?
    public var connectionName: String?
    public var appVersion: String?

    public var asParameters: Parameters {
        guard
        let trustID = trustID,
        let appName = appName,
        let bundleID = bundleID,
        let latitude = latitude,
        let longitude = longitude,
        let connectionType = connectionType,
        let connectionName = connectionName,
        let appVersion = appVersion else {return [:]}
        
        let device = Device.current
        
        return [
            "trust_id": trustID,
            "app_name": appName,
            "bundle_id": bundleID,
            "os": "IOS",
            "os_version": device.systemVersion ?? .zero,
            "device_name": Sysctl.model,
            "latGeo": latitude,
            "lonGeo": longitude,
            "connection_type": connectionType,
            "connection_name": connectionName,
            "version_app": appVersion
        ]
    }
}

public struct Transaction: Parameterizable {
    public var type: String?
    public var result: String?
    public var timestamp: String?
    public var method: String?
    public var operation: String?

    public var asParameters: Parameters {
        guard
            let type = type,
            let result = result,
            let timestamp = timestamp,
            let method = method,
            let operation = operation else {return [:]}

        return [
            "type": type,
            "result": result,
            "timestamp": timestamp,
            "method": method,
            "operation": operation
        ]
    }
}

// MARK: - RegisterFirebaseTokenParameters
struct RegisterFirebaseTokenParameters: Parameterizable {
    var firebaseToken: String?
    var bundleID: String?
    
    private var trustID: String? {
        return trustIDManager.getTrustID()
    }
    
    private var trustIDManager: TrustIDManagerProtocol {
        return TrustIDManager()
    }
    
    public var asParameters: Parameters {
        guard
            let trustID = trustID,
            let firebaseToken = firebaseToken,
            let bundleID = bundleID else {
                return [:]
        }
        
        return [
            "trust_id": trustID,
            "firebase_token": firebaseToken,
            "bundle_id": bundleID,
            "platform": "IOS"
        ]
    }
}

// MARK: - DeviceInfoParameters
struct DeviceInfoParameters: Parameterizable {
    var identityInfo: IdentityInfoDataSource?
    var networkInfo: CTTelephonyNetworkInfo?
    var trustID: String? {
        return trustIDManager.getTrustID()
    }
    
    private var trustIDManager: TrustIDManagerProtocol {
        return TrustIDManager()
    }

    public var asParameters: Parameters {
        let systemName = "iOS"
        let device = Device.current
        let uiDevice = UIDevice()
        
        var trustIDManager: TrustIDManagerProtocol {
            return TrustIDManager()
        }

        var parameters: Parameters = [:]
        
        var deviceParameters: [String : Any] = [
            "activeCPUs": Sysctl.activeCPUs,
            "hostname": Sysctl.hostName,
            "model": Sysctl.machine,
            "machine": Sysctl.model,
            "osRelease": Sysctl.osRelease,
            "osType": Sysctl.osType,
            "osVersion": Sysctl.osVersion,
            "version": Sysctl.version,
            "description": device.description,
            "screenBrightness": device.screenBrightness,
            "screenDiagonalLength": device.diagonal,
            "totalDiskSpace": DiskStatus.totalDiskSpace,
            "identifierForVendor": uiDevice.identifierForVendor?.uuidString ?? "",
            "system_name": systemName
        ]
        
        if let batteryLevel = device.batteryLevel {
            deviceParameters.updateValue(batteryLevel, forKey: "batteryLevel")
        }
        
        if let localizedModel = device.localizedModel {
            deviceParameters.updateValue(localizedModel, forKey: "localizedModel")
        }
        
        if let deviceModel = device.model {
            deviceParameters.updateValue(deviceModel, forKey: "deviceModel")
        }
        
        if let name = device.name {
            deviceParameters.updateValue(name, forKey: "name")
        }
        
        if let screenPPI = device.ppi {
            deviceParameters.updateValue(screenPPI, forKey: "screenPPI")
        }
        
        if let systemOS = device.systemName {
            deviceParameters.updateValue(systemOS, forKey: "systemOS")
        }
        
        if let systemVersion = device.systemVersion {
            deviceParameters.updateValue(systemVersion, forKey: "systemVersion")
        }
        
        parameters.updateValue(deviceParameters, forKey: "device")
        
        if let trustID = trustIDManager.getTrustID() {
            parameters.updateValue(trustID, forKey: "trust_id")
        }
        
        if let identityInfo = identityInfo {
            var identity = ["dni": identityInfo.dni]
            
            if let name = identityInfo.name {
                identity.updateValue(name, forKey: "name")
            }
            
            if let lastname = identityInfo.lastname {
                identity.updateValue(lastname, forKey: "lastname")
            }
            
            if let email = identityInfo.email {
                identity.updateValue(email, forKey: "email")
            }
            
            if let phone = identityInfo.phone {
                identity.updateValue(phone, forKey: "phone")
            }
            
            parameters.updateValue(identity, forKey: "identity")
        }
        
        guard
            let serviceSubscriberCellularProviders = networkInfo?.serviceSubscriberCellularProviders,
            !serviceSubscriberCellularProviders.isEmpty,
            let carrierKey =  serviceSubscriberCellularProviders.keys.first,
            let carrier = serviceSubscriberCellularProviders[carrierKey] else {
                return parameters
        }
        
        let carrierInfo = [
            [
                "carrierName": carrier.carrierName ?? "",
                "mobileCountryCode": carrier.mobileCountryCode ?? "",
                "mobileNetworkCode": carrier.mobileNetworkCode ?? "",
                "ISOCountryCode": carrier.isoCountryCode ?? "",
                "allowsVOIP": carrier.allowsVOIP ? "YES" : "NO"
            ]
        ]
        
        parameters.updateValue(carrierInfo, forKey: "sim")
        
        return parameters
    }
}
