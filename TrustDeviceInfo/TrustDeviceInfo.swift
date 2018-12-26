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

// MARK: - OnSIMChangedDelegate
public protocol OnSIMChangedDelegate: AnyObject {
    func onCarrierInfoHasChanged(carrier: CTCarrier)
}

// MARK: - OnSendDataResponseDelegate
public protocol OnSendDataResponseDelegate: AnyObject {
    func onResponse(responseStatus: ResponseStatus)
}

// MARK: - OnTrustIDDelegate
public protocol OnTrustIDDelegate: AnyObject {
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

    private var sendDataOnEnabled: Bool = false
    
    private var enable = false {
        didSet {
            if enable && !oldValue {
                setCarrierUpdateNotifier()
                
                guard sendDataOnEnabled else {
                    return
                }
                
                sendDeviceInfo()
            } else if !enable && oldValue {
                print("Disabled")
            }
        }
    }
    
    private static var trustDeviceInfo: TrustDeviceInfo = {
        return TrustDeviceInfo()
    }()

    private init() {}
    
    deinit {
        disable()
    }
    
    public static var shared: TrustDeviceInfo {
        return trustDeviceInfo
    }
    
    public weak var onSIMChangedDelegate: OnSIMChangedDelegate?
    public weak var onSendDataResponseDelegate: OnSendDataResponseDelegate?
    public weak var onTrustIDDelegate: OnTrustIDDelegate?
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
        let updateNotifier: ((CTCarrier) -> Void) = {
            carrier in
            
            DispatchQueue.main.async {
                [weak self] in
                
                guard let self = self else {
                    return
                }
                
                if self.checkTrustIDhasBeenSaved() {
                    self.send(carrierData: carrier)
                } else {
                    self.sendDeviceInfo()
                }
                
                guard let delegate = self.onSIMChangedDelegate else {
                    return
                }
                
                delegate.onCarrierInfoHasChanged(carrier: carrier)
            }
        }

        networkInfo.subscriberCellularProviderDidUpdateNotifier = updateNotifier
        
        /*let _updateNotifier: ((String) -> Void) = {
            carrier in
            print("subscriberCellularProviderDidUpdateNotifier Carrier: \(carrier)")
            /*DispatchQueue.main.async {
                [weak self] in
                
                guard let self = self else {
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
            }*/
        }
        
        networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = _updateNotifier*/
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
    
    func send(carrierData: CTCarrier) {
        
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
    }
    
    public func sendDeviceInfo(completionHandler: ((ResponseStatus) -> Void)? = nil) {
        
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

                guard let self = self else {
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
}
    
// MARK: - TrustID Persistance related methods
extension TrustDeviceInfo {
    public func checkTrustIDhasBeenSaved() -> Bool {
        return KeychainWrapper.standard.string(forKey: trustIDKey) != nil
    }
    
    public func getTrustID() -> String? {
        return KeychainWrapper.standard.string(forKey: trustIDKey)
    }

    private func save(trustID: String) {
        if !checkTrustIDhasBeenSaved() {
            KeychainWrapper.standard.set(trustID, forKey: trustIDKey)
        }

        if let delegate = onTrustIDDelegate {
            delegate.onTrustIDSaved()
        }
    }
    
    private func removeTrustID() {
        KeychainWrapper.standard.removeObject(forKey: trustIDKey)
    }
}

// MARK: - Parameters Helpers
extension TrustDeviceInfo {
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
        
        if let trustID = getTrustID() {
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
    
    private func getEventInfoAsParameters(carrier: CTCarrier) -> Parameters? {
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
    }
}
