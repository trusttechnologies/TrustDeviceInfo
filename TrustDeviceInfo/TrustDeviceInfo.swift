//
//  TrustDeviceInfo.swift
//  Trust
//
//  Created by Diego Villouta Fredes on 7/25/18.
//  Copyright © 2018 Jumpitt Labs. All rights reserved.
//

import Alamofire
import CoreTelephony
import DeviceKit
import Foundation
import UIKit

// MARK: Extension Bundle
extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}

// MARK: - Extension String
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

// MARK: - OnSIMChangedDelegate
public protocol OnSIMChangedDelegate: class {
    func onCarrierInfoHasChanged(carrier: CTCarrier)
}

// MARK: - OnSendDataResponseDelegate
public protocol OnSendDataResponseDelegate: class {
    func onResponse(responseStatus: ResponseStatus)
}

// MARK: - OnTrustIDDelegate
public protocol OnTrustIDDelegate: class {
    func onTrustIDSaved()
}

// MARK: - ResponseStatus
public enum ResponseStatus: String {
    case created = "TrustID Creado"
    case noChanges = "No hay cambios"
    case updated = "Datos actualizados"
    case error = "Ha ocurrido un error en el envío de datos"
}

// MARK: - DeviceInfo
public class TrustDeviceInfo {
    
    private let trustIDKey = "trustid"
    private let baseUrl = "https://audit.trust.lat/api"
    private let apiVersion = "/v1"
    
    private var trifleUploadURLAsString: String {
        return "\(baseUrl)\(apiVersion)/trifle"
    }
    
    private var carrierChangeEventUploadURLAsString: String {
        return "\(baseUrl)\(apiVersion)/trifle/remote"
    }
    
    private var eventUploadURLAsString: String {
        return "\(baseUrl)\(apiVersion)/audit"
    }
    
    private let networkInfo = CTTelephonyNetworkInfo()

    private var autoSendDataOnEnabled: Bool = false
    
    private var enable = false {
        didSet {
            if enable && !oldValue {
                setCarrierUpdateNotifier()
                
                guard autoSendDataOnEnabled else {
                    return
                }
                
                sendData()
            } else if !enable && oldValue {
                print("Disabled")
            }
        }
    }
    
    public class var shared: TrustDeviceInfo {
        struct Static {
            static let deviceInfo = TrustDeviceInfo()
        }

        return Static.deviceInfo
    }
    
    public weak var onSIMChangedDelegate: OnSIMChangedDelegate?
    public weak var onSendDataResponseDelegate: OnSendDataResponseDelegate?
    public weak var onTrustIDDelegate: OnTrustIDDelegate?
    
    private init() {}
    
    deinit {
        enable = false
    }
}

extension TrustDeviceInfo {
    private func setCarrierUpdateNotifier() {
        let updateNotifier: ((CTCarrier) -> Void) = {
            carrier in
            
            DispatchQueue.main.async {
                [weak self] in
                
                guard let `self` = self else {
                    return
                }
                
                if self.checkTrustIDhasBeenSaved() {
                    self.send(carrierData: carrier)
                } else {
                    self.sendData()
                }
                
                guard let delegate = self.onSIMChangedDelegate else {
                    return
                }
                
                delegate.onCarrierInfoHasChanged(carrier: carrier)
            }
        }

        networkInfo.subscriberCellularProviderDidUpdateNotifier = updateNotifier
    }

    private func getResponseStatus(response: HTTPURLResponse?) -> ResponseStatus {
        
        guard let statusCode = response?.statusCode else {
            return .error
        }
        
        switch statusCode {
        case 200:
            guard checkTrustIDhasBeenSaved() else {
                return .created
            }

            return .noChanges
        case 201:
            return .updated
        default:
            return .error
        }
    }
    
    public func enable(autoSendDataOnEnabled: Bool = true) {
        self.autoSendDataOnEnabled = autoSendDataOnEnabled
        self.enable = true
    }
    
    public func disable() {
        self.enable = false
    }
    
    func send(carrierData: CTCarrier) {
        
        guard let parameters = getEventInfoAsParameters(carrier: carrierData) else {
            return
        }
        
        print("Parameters: \(parameters)")
        
        request(
            carrierChangeEventUploadURLAsString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default).responseJSON {
                [weak self] response in
                
                print("Status code: \(response.response?.statusCode ?? -1)")
                print("Carrier Change response: \(response)")
                
                guard let `self` = self else {
                    return
                }
                
                switch response.result {
                case .success(let responseData):
                    guard
                        let json = responseData as? [String: Any],
                        let trifle = json["trifle"] as? [String: Any] else {
                            return
                    }
                    
                    guard let trustID = trifle[self.trustIDKey] as? String else {
                        print("No TrustID")
                        self.removeTrustID()
                        return
                    }
                    
                    print("TrustID: \(trustID)")
                    self.save(trustID: trustID)
                    
                    if let delegate = self.onTrustIDDelegate {
                        delegate.onTrustIDSaved()
                    }
                default: break
                }
        }
    }
    
    public func sendData(completionHandler: ((ResponseStatus) -> Void)? = nil) {
        
        guard let parameters = getDeviceInfoAsParameters() else {
            return
        }
        
        request(
            trifleUploadURLAsString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default).responseJSON {
                [weak self] response in
                
                print("Status code: \(response.response?.statusCode ?? -1)")
                print("Trifle response: \(response)")
                
                guard let `self` = self else {
                    return
                }
                
                let httpResponse = response.response
                
                if let delegate = self.onSendDataResponseDelegate {
                    delegate.onResponse(responseStatus: self.getResponseStatus(response: httpResponse))
                }
                
                if let completionHandler = completionHandler {
                    completionHandler(self.getResponseStatus(response: httpResponse))
                }
                
                switch response.result {
                case .success(let responseData):
                    guard
                        let json = responseData as? [String: Any],
                        let trifle = json["trifle"] as? [String: Any] else {
                            return
                    }
                    
                    guard let trustID = trifle[self.trustIDKey] as? String else {
                        print("No TrustID")
                        self.removeTrustID()
                        return
                    }
                    
                    print("TrustID: \(trustID)")
                    self.save(trustID: trustID)
                default: break
                }
        }
    }

    public func send(eventData: EventData, onResponse: (()->Void)? = nil, onSuccess: (()->Void)? = nil, onFailure: (()->Void)? = nil) {
        
        let parameters = eventData.asParameters
        
        request(
            eventUploadURLAsString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default).responseJSON {
                response in
                
                print("Status code: \(response.response?.statusCode ?? -1)")
                print("Event response: \(response)")
                
                if let onResponse = onResponse {
                    onResponse()
                }
                
                switch response.result {
                case .success:
                    if let onSuccess = onSuccess {
                        onSuccess()
                    }
                case .failure:
                    if let onFailure = onFailure {
                        onFailure()
                    }
                }
        }
    }
    
    private func save(trustID: String) {
        KeychainWrapper.standard.set(trustID, forKey: trustIDKey)
        
        if let delegate = onTrustIDDelegate {
            delegate.onTrustIDSaved()
        }
    }
    
    public func getTrustID() -> String {
        
        guard let trustID = KeychainWrapper.standard.string(forKey: trustIDKey) else {
            return ""
        }
        
        return trustID
    }
    
    private func removeTrustID() {
        KeychainWrapper.standard.removeObject(forKey: trustIDKey)
    }
    
    public func checkTrustIDhasBeenSaved() -> Bool {
        return KeychainWrapper.standard.string(forKey: trustIDKey) != nil
    }
    
    private func getEventInfoAsParameters(carrier: CTCarrier) -> Parameters? {
        
        guard enable else {
            return nil
        }

        let parameters: Parameters = [
            "trustid": getTrustID(),
            "object": [
                "carrierName": carrier.carrierName ?? "",
                "mobileCountryCode": carrier.mobileCountryCode ?? "",
                "mobileNetworkCode": carrier.mobileNetworkCode ?? "",
                "ISOCountryCode": carrier.isoCountryCode ?? "",
                "allowsVOIP": carrier.allowsVOIP ? "YES" : "NO"
                ],
            "key": "",
            "value": "",
            "geo": [
                "lat": "-32",
                "long": "-77"
            ]
        ]
        
        return parameters
    }
    
    private func getDeviceInfoAsParameters() -> Parameters? {
        
        guard enable else {
            return nil
        }
        
        let device = Device()
        let uiDevice = UIDevice()
        
        var parameters: Parameters = [
            "device": [
                "activeCPUs": Sysctl.activeCPUs,
                "hostname": Sysctl.hostName,
                "model": Sysctl.machine,
                "machine": Sysctl.model,
                "osRelease": Sysctl.osRelease,
                "osType": Sysctl.osType,
                "osVersion": Sysctl.osVersion,
                "version": Sysctl.version,
                "batteryLevel": device.batteryLevel,
                "description": device.description,
                "localizedModel": device.localizedModel,
                "deviceModel": device.model,
                "name": device.name,
                "screenBrightness": device.screenBrightness,
                "screenDiagonalLength": device.diagonal,
                "screenPPI": device.ppi ?? "",
                "systemOS": device.systemName,
                "systemVersion": device.systemVersion,
                "totalDiskSpace": DiskStatus.totalDiskSpace,
                "identifierForVendor": uiDevice.identifierForVendor?.uuidString ?? ""
            ]
        ]
        
        defer {
            print("Parameters: °\(parameters)")
        }
        
        if checkTrustIDhasBeenSaved() {
            let trustID = getTrustID()
            
            parameters.updateValue(trustID, forKey: trustIDKey)
        }
        
        guard
            let serviceSubscriberCellularProviders = networkInfo.serviceSubscriberCellularProviders,
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
