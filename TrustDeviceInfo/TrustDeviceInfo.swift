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

// MARK: - TrustDeviceInfo
public class TrustDeviceInfo {
    private let trustIDKey = "trustid"
    private let deviceKey = "\(Sysctl.model)\(DiskStatus.totalDiskSpace)"
    
    private var sendDeviceInfoOnEnabled: Bool = false
    
    private var enable = false {
        didSet {
            if enable && !oldValue {
                setCarrierUpdateNotifier()
                
                guard sendDeviceInfoOnEnabled else {
                    return
                }
                
                sendDeviceInfo()
            } else if !enable && oldValue {
                disableCarrierUpdateNotifier()
            }
        }
    }
    
    // MARK: - Private instance
    private static var trustDeviceInfo: TrustDeviceInfo = {
        return TrustDeviceInfo()
    }()

    // MARK: - Shared instance
    public static var shared: TrustDeviceInfo {
        return trustDeviceInfo
    }

    // MARK: - TrustIDManager
    private lazy var trustIDManager: TrustIDManagerProtocol = {
        let trustIDManager = TrustIDManager()
        
        trustIDManager.managerOutput = self
        
        return trustIDManager
    }()
    
    // MARK: - APIManager
    private lazy var apiManager: APIManagerProtocol = {
        let apiManager = APIManager()
        
        apiManager.managerOutput = self
        
        return apiManager
    }()
    
    // MARK: - NetworkInfo
    private lazy var networkInfo: CTTelephonyNetworkInfo = {
        let networkInfo = CTTelephonyNetworkInfo()
        return networkInfo
    }()
    
    // MARK: - Delegates
    public weak var simInfoDelegate: SIMInfoDelegate?
    public weak var sendDeviceInfoDelegate: SendDeviceInfoDelegate?
    public weak var trustIDDelegate: TrustIDDelegate?
    
    public var sendDeviceInfoCompletionHandler: ((ResponseStatus) -> Void)?
    
    // MARK: - Private Init
    private init() {}
    
    deinit {
        disable()
    }
}

// MARK: - Enable/Disable TrustDeviceInfo
extension TrustDeviceInfo {
    public func enable(sendDeviceInfoOnEnabled: Bool = true) {
        self.sendDeviceInfoOnEnabled = sendDeviceInfoOnEnabled
        enable = true
    }

    public func disable() {
        enable = false
    }
}

// MARK: - Enable/Disable CarrierUpdateNotifier
extension TrustDeviceInfo {
    private func setCarrierUpdateNotifier() {
        let updateNotifier: ((String) -> Void) = {
            carrier in

            DispatchQueue.main.async {
                [weak self] in

                guard let self = self else {
                    return
                }

                self.sendDeviceInfo()

                guard let delegate = self.simInfoDelegate else {
                    return
                }

                delegate.onCarrierInfoHasChanged(carrier: carrier)
            }
        }

        networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = updateNotifier
    }
    
    private func disableCarrierUpdateNotifier() {
        networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = nil
    }
}

// MARK: - SendDeviceInfo related methods
extension TrustDeviceInfo {
    private func getResponseStatus(response: HTTPURLResponse?) -> ResponseStatus {
        guard let statusCode = response?.statusCode else {
            return .error
        }

        switch statusCode {
        case 200:
            guard trustIDManager.hasTrustIDBeenSaved() else {
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
        let parameters = DeviceInfoParameters(identityInfo: identityInfo, networkInfo: networkInfo)
        
        apiManager.sendDeviceInfo(with: parameters)
        
        sendDeviceInfoCompletionHandler = completionHandler
    }
    
    public func setAppState(dni: String, bundleID: String) {
        
        let parameters = AppStateParameters(dni: dni, bundleID: bundleID)
        
        apiManager.setAppState(with: parameters)
    }
}

// MARK: - TrustID related methods
extension TrustDeviceInfo {
    public func hasTrustIDBeenSaved() -> Bool {
        return getTrustID() != nil
    }
    
    public func getTrustID() -> String? {
        return trustIDManager.getTrustID()
    }
}
    
// MARK: - APIManagerOutputProtocol
extension TrustDeviceInfo: APIManagerOutputProtocol {
    func onSendDeviceInfoResponse(response: DataResponse<Any>) {
        let httpResponse = response.response
        
        sendDeviceInfoDelegate?.onResponse(status: getResponseStatus(response: httpResponse))
        sendDeviceInfoCompletionHandler?(getResponseStatus(response: httpResponse))
    }

    func onSendDeviceInfoSuccess(response: Any) {
        guard let json = response as? [String: Any], let status = json["status"] as? Bool else {
            return
        }

        guard status else {
            return
        }
        
        guard let trustID = json[trustIDKey] as? String else {
            print("No TrustID")
            return
        }
        
        print("TrustID: \(trustID)")
        trustIDManager.save(trustID: trustID)
    }
    
    // MARK: - Unused
    func onSendDeviceInfoFailure() {print("onSendDeviceInfoFailure")}
    
    // MARK: - Unused
    func onSetAppStateResponse() {print("onSetAppStateResponse")}
    func onSetAppStateSuccess() {print("onSetAppStateSuccess")}
    func onSetAppStateFailure() {print("onSetAppStateFailure")}
}

// MARK: - TrustIDManagerOutputProtocol
extension TrustDeviceInfo: TrustIDManagerOutputProtocol {
    func onTrustIDSaved() {
        trustIDDelegate?.onTrustIDSaved()
    }
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

//private let deviceInfoURL = "/identification"
//private let deviceInfoEndpoint = "/device"

//private let auditURL = "/audit"
//private let auditEndpoint = "/audit"

/*private let appStateURL = "/company"
 private let appStateEndpoint = "/app/state"*/

/*private lazy var deviceInfoCompleteURLAsString: String = {
 return "\(baseUrl)\(deviceInfoURL)\(apiVersion)\(deviceInfoEndpoint)"
 }()*/

/*private lazy var auditCompleteURLAsString: String = {
 return "\(baseUrl)\(auditURL)\(apiVersion)\(auditEndpoint)"
 }()*/

/*private lazy var appStateCompleteURLAsString: String = {
 return "\(baseUrl)\(appStateURL)\(apiVersion)\(appStateEndpoint)"
 }()*/

/*
 public func sendDeviceInfo(identityInfo: IdentityInfoDataSource? = nil, completionHandler: ((ResponseStatus) -> Void)? = nil) {
 guard let parameters = getDeviceInfoAsParameters(identityInfo: identityInfo) else {
 return
 }
 
 print("URLRequested: \(deviceInfoCompleteURLAsString)")
 
 request(
 deviceInfoCompleteURLAsString,
 method: .post,
 parameters: parameters.asParameters,
 encoding: JSONEncoding.default).responseJSON {
 [weak self] response in
 
 print("Status code: \(response.response?.statusCode ?? -1)")
 print("Response: \(response)")
 
 guard let self = self else {
 return
 }
 
 let httpResponse = response.response
 
 if let delegate = self.sendDeviceInfoDelegate {
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
 self.trustIDManager.save(trustID: trustID)
 default: break
 }
 }*/
    
    /*
     public func setAppState(dni: String, bundleID: String) {
     let parameters = AppStateParameters(dni: dni, bundleID: bundleID).asParameters
     
     print("URLRequested: \(appStateCompleteURLAsString)")
     
     request(
     appStateCompleteURLAsString,
     method: .post,
     parameters: parameters,
     encoding: JSONEncoding.default).responseJSON {
     response in
     
     print("Status code: \(response.response?.statusCode ?? -1)")
     print("Response: \(response)")
     }
     }*/

    /*public func send(eventData: EventData, onResponse: (()->Void)? = nil, onSuccess: (()->Void)? = nil, onFailure: (()->Void)? = nil) {
        
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
    }*/

// MARK: - Parameters Helpers
/*extension TrustDeviceInfo {
    private func getDeviceInfoAsParameters(identityInfo: IdentityInfoDataSource? = nil) -> Parameters? {
        guard enable else {
            return nil
        }
        
        let systemName = "iOS"

        let device = Device.current
        let uiDevice = UIDevice()

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

        defer {
            print("Parameters: °\(parameters)")
        }

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
}*/
