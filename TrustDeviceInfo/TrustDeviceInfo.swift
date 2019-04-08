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

// MARK: - IdentityInfoDataSource
public protocol IdentityInfoDataSource {
    var dni: String {get set}
    var name: String? {get set}
    var lastname: String? {get set}
    var email: String? {get set}
    var phone: String? {get set}
}

// MARK: - SIMInfoDelegate
public protocol SIMInfoDelegate: AnyObject {
    func onCarrierInfoHasChanged(carrier: CTCarrier)
    func onCarrierInfoHasChanged(carrier: String)
}

// MARK: - SendDataDelegate
public protocol SendDeviceInfoDelegate: AnyObject {
    func onResponse(status: ResponseStatus)
}

// MARK: - TrustIDDelegate
public protocol TrustIDDelegate: AnyObject {
    func onTrustIDSaved()
}

// MARK: - ResponseStatus
public enum ResponseStatus: String {
    case created = "TrustID Creado"
    case noChanges = "No hay cambios"
    case updated = "Datos actualizados"
    case error = "Ha ocurrido un error en el envío de datos"
}

// MARK: - TrustDeviceInfo
public class TrustDeviceInfo {

    private let trustIDKey = "trustid"

    private let baseUrl = "http://api.trust.lat"
    private let apiVersion = "/api/v1"

    private let deviceInfoURL = "/identification"
    private let deviceInfoEndpoint = "/device"

    private let auditURL = "/audit"
    private let auditEndpoint = "/audit"

    private lazy var deviceInfoCompleteURLAsString: String = {
        return "\(baseUrl)\(deviceInfoURL)\(apiVersion)\(deviceInfoEndpoint)"
    }()

    private lazy var auditCompleteURLAsString: String = {
        return "\(baseUrl)\(auditURL)\(apiVersion)\(auditEndpoint)"
    }()

    private lazy var networkInfo: CTTelephonyNetworkInfo = {
        let networkInfo = CTTelephonyNetworkInfo()
        return networkInfo
    }()

    private var sendDataOnEnabled: Bool = false
    
    private var enable = false {
        didSet {
            if enable && !oldValue {
                setCarrierUpdateNotifier()
                
                guard sendDataOnEnabled else {
                    return
                }
                
                sendDeviceInfo()
            }
        }
    }

    private static var trustDeviceInfo: TrustDeviceInfo = {
        return TrustDeviceInfo()
    }()

    public static var shared: TrustDeviceInfo {
        return trustDeviceInfo
    }

    // MARK: - Delegates
    public weak var SIMInfoDelegate: SIMInfoDelegate?
    public weak var sendDataDelegate: SendDeviceInfoDelegate?
    public weak var trustIDDelegate: TrustIDDelegate?
    
    private init() {}
    
    deinit {
        disable()
    }
}

// MARK: - TrustDeviceInfo
extension TrustDeviceInfo {
    public func enable(sendDataOnEnabled: Bool = true) {
        self.sendDataOnEnabled = sendDataOnEnabled
        enable = true
    }

    public func disable() {
        enable = false
    }

    private func setCarrierUpdateNotifier() {
        let updateNotifier: ((String) -> Void) = {
            carrier in

            DispatchQueue.main.async {
                [weak self] in

                guard let self = self else {
                    return
                }

                self.sendDeviceInfo()

                guard let delegate = self.SIMInfoDelegate else {
                    return
                }

                delegate.onCarrierInfoHasChanged(carrier: carrier)
            }
        }

        networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = updateNotifier
    }
}

// MARK: - SendData related methods
extension TrustDeviceInfo {
    private func getResponseStatus(response: HTTPURLResponse?) -> ResponseStatus {
        guard let statusCode = response?.statusCode else {
            return .error
        }

        switch statusCode {
        case 200:
            guard hasTrustIDBeenSaved() else {
                return .created
            }
            return .noChanges
        case 201:
            return .updated
        default:
            return .error
        }
    }

    public func sendDeviceInfo(identityInfo: IdentityInfoDataSource? = nil, completionHandler: ((ResponseStatus) -> Void)? = nil) {
        guard let parameters = getDeviceInfoAsParameters(identityInfo: identityInfo) else {
            return
        }

        request(
            deviceInfoCompleteURLAsString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default).responseJSON {
                [weak self] response in

                print("Status code: \(response.response?.statusCode ?? -1)")
                print("Response: \(response)")

                guard let self = self else {
                    return
                }

                let httpResponse = response.response

                if let delegate = self.sendDataDelegate {
                    delegate.onResponse(status: self.getResponseStatus(response: httpResponse))
                }

                if let completionHandler = completionHandler {
                    completionHandler(self.getResponseStatus(response: httpResponse))
                }

                switch response.result {
                case .success(let responseData):
                    guard
                        let json = responseData as? [String: Any],
                        let status = json["status"] as? Bool else {
                            return
                    }

                    guard status else {
                        return
                    }
                    
                    guard let trustID = json[self.trustIDKey] as? String else {
                        print("No TrustID")
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
            auditCompleteURLAsString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default)
            .responseJSON {
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
    /*func send(carrierData: CTCarrier) {
     guard let parameters = getEventInfoAsParameters(carrier: carrierData) else {
     return
     }
     
     request(
     carrierChangeEventUploadURLAsString,
     method: .post,
     parameters: parameters,
     encoding: JSONEncoding.default).responseJSON {
     [weak self] response in
     
     print("Status code: \(response.response?.statusCode ?? -1)")
     print("Carrier Change response: \(response)")
     
     guard let self = self else {
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
     return
     }
     
     print("TrustID: \(trustID)")
     self.save(trustID: trustID)
     default: break
     }
     }
     }*/
}
    
// MARK: - TrustID Persistance related methods
extension TrustDeviceInfo {
    public func hasTrustIDBeenSaved() -> Bool {
        return getTrustID() != nil
    }

    public func getTrustID() -> String? {
        return KeychainWrapper.standard.string(forKey: trustIDKey)
    }

    private func save(trustID: String) {
        if !hasTrustIDBeenSaved() {
            KeychainWrapper.standard.set(trustID, forKey: trustIDKey)
        }

        if let delegate = trustIDDelegate {
            delegate.onTrustIDSaved()
        }
    }

    private func removeTrustID() {
        KeychainWrapper.standard.removeObject(forKey: trustIDKey)
    }
}

// MARK: - Parameters Helpers
extension TrustDeviceInfo {
    private func getDeviceInfoAsParameters(identityInfo: IdentityInfoDataSource? = nil) -> Parameters? {
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
        
        if let trustID = getTrustID() {
            parameters.updateValue(trustID, forKey: trustIDKey)
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
    /*private func getEventInfoAsParameters(carrier: CTCarrier) -> Parameters? {
        guard
            enable,
            let trustId = getTrustID() else {
                return nil
        }
        
        let parameters: Parameters = [
            "trustid": trustId,
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
        
        defer {
            print("Parameters: °\(parameters)")
        }
        
        return parameters
    }*/
}
