//
//  DeviceInfo.swift
//  Trust
//
//  Created by Diego Villouta Fredes on 7/25/18.
//  Copyright © 2018 Jumpitt Labs. All rights reserved.
//

import Foundation
import UIKit
import CoreTelephony
import DeviceKit
import Alamofire

public protocol OnSIMChangedDelegate: class {
    func onCarrierInfoHasChanged(carrier: CTCarrier)
}

public protocol OnSendDataResponseDelegate: class {
    func onResponse(responseStatus: ResponseStatus)
    func onTrustIDSaved()
}

public enum ResponseStatus: String {
    case created = "TrustID Creado"
    case noChanges = "No hay cambios"
    case updated = "Datos actualizados"
    case error = "Ha ocurrido un error en el envío de datos"
}

public class DeviceInfo {
    
    private let trustIDKey = "trustid"
    private let baseUrl = "https://audit.trust.lat/api"
    private let apiVersion = "/v1"
    private let trifleUploadURLAsString = "https://audit.trust.lat/api/v1/trifle"
    private let eventUploadURLAsString = "https://audit.trust.lat/api/v1/trifle/remote"
    private let networkInfo = CTTelephonyNetworkInfo()

    private var autoSendDataOnEnabled: Bool = false
    
    private var enable = false {
        didSet {
            if enable == true && oldValue == false {
                setCarrierUpdateNotifier()
                
                guard autoSendDataOnEnabled else {
                    return
                }
                
                sendData()
            } else if enable == false && oldValue == true {
                print("Disabled")
            }
        }
    }
    
    public class var shared: DeviceInfo {
        struct Static {
            static let deviceInfo = DeviceInfo()
        }
        
        return Static.deviceInfo
    }
    
    public weak var onSIMChangedDelegate: OnSIMChangedDelegate?
    public weak var onSendDataResponseDelegate: OnSendDataResponseDelegate?
    
    private init() {}
    
    deinit {
        enable = false
    }
}

extension DeviceInfo {
    private func setCarrierUpdateNotifier() {
        let updateNotifier: ((CTCarrier) -> Void) = {
            carrier in
            
            DispatchQueue.main.async {
                [weak self] in
                
                guard let `self` = self else {
                    return
                }
                
                if self.checkTrustIDhasBeenSaved() {
                    self.sendEventData(carrier: carrier)
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
    
    private func save(trustID: String) {
        UserDefaults.standard.set(trustID, forKey: trustIDKey)
    }
    
    func enable(autoSendDataOnEnabled: Bool = true) {
        self.autoSendDataOnEnabled = autoSendDataOnEnabled
        self.enable = true
    }
    
    func disable() {
        self.enable = false
    }
    
    func sendData(completionHandler: ((ResponseStatus) -> Void)? = nil) {
        
        guard let parameters = getInfoAsParameters() else {
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
                    
                    if let delegate = self.onSendDataResponseDelegate {
                        delegate.onTrustIDSaved()
                    }
                default: break
                }
        }
    }
    
    func sendEventData(carrier: CTCarrier) {
        
        guard let parameters = getEventInfoAsParameters(carrier: carrier) else {
            return
        }
        
        print("Parameters: \(parameters)")
        
        request(
            eventUploadURLAsString,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default).responseJSON {
                [weak self] response in
                
                print("Status code: \(response.response?.statusCode ?? -1)")
                print("Event response: \(response)")
                
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
                    //self.save(trustID: trustID)
                    
                    if let delegate = self.onSendDataResponseDelegate {
                        delegate.onTrustIDSaved()
                    }
                default: break
                }
        }
    }
    
    func getTrustID() -> String {
        guard let trustID = UserDefaults.standard.string(forKey: trustIDKey) else {
            return ""
        }
        
        return trustID
    }
    
    private func removeTrustID() {
        UserDefaults.standard.removeObject(forKey: trustIDKey)
    }
    
    func checkTrustIDhasBeenSaved() -> Bool {
        return UserDefaults.standard.string(forKey: trustIDKey) != nil
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
    
    private func getInfoAsParameters() -> Parameters? {
        
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
        
        guard let carrier = networkInfo.subscriberCellularProvider else {
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

// MARK: - DiskStatus
private class DiskStatus {
    
    class func MBFormatter(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        
        formatter.allowedUnits = .useMB
        formatter.countStyle = .decimal
        formatter.includesUnit = false
        
        return formatter.string(fromByteCount: bytes) as String
    }
    
    class var totalDiskSpace: String {
        get {
            
            let formatter = ByteCountFormatter()
            
            formatter.allowedUnits = .useGB
            formatter.countStyle = .decimal
            formatter.includesUnit = false
            
            let totalDiskSpace = formatter.string(fromByteCount: totalDiskSpaceInBytes).replacingOccurrences(of: ",", with: ".")
            
            guard let totalDiskSpaceAsDouble = Double(totalDiskSpace) else {
                return ""
            }
            
            var totalDiskSpaceAsString = String(format: "%.f", totalDiskSpaceAsDouble)
            
            switch totalDiskSpaceAsDouble {
            case 0...33:
                totalDiskSpaceAsString = "32"
            case 34...65:
                totalDiskSpaceAsString = "64"
            case 66...129:
                totalDiskSpaceAsString = "128"
            case 130...257:
                totalDiskSpaceAsString = "256"
            default: break
            }
            
            return totalDiskSpaceAsString
        }
    }
    
    class var freeDiskSpace: String {
        get {
            return ByteCountFormatter.string(fromByteCount: freeDiskSpaceInBytes, countStyle: .binary)
        }
    }
    
    class var usedDiskSpace: String {
        get {
            return ByteCountFormatter.string(fromByteCount: usedDiskSpaceInBytes, countStyle: .binary)
        }
    }
    
    class var totalDiskSpaceInBytes: Int64 {
        get {
            do {
                let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                let space = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value
                return space!
            } catch {
                return 0
            }
        }
    }
    
    class var freeDiskSpaceInBytes: Int64 {
        get {
            do {
                let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
                return freeSpace!
            } catch {
                return 0
            }
        }
    }
    
    class var usedDiskSpaceInBytes: Int64 {
        get {
            let usedSpace = totalDiskSpaceInBytes - freeDiskSpaceInBytes
            return usedSpace
        }
    }
}

// MARK: - Sysctl
private struct Sysctl {
    
    enum Error: Swift.Error {
        case unknown
        case malformedUTF8
        case invalidSize
        case posixError(POSIXErrorCode)
    }
    
    static func dataForKeys(_ keys: [Int32]) throws -> [Int8] {
        return try keys.withUnsafeBufferPointer() { keysPointer throws -> [Int8] in
            var requiredSize = 0
            let preFlightResult = Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress), UInt32(keys.count), nil, &requiredSize, nil, 0)
            
            if preFlightResult != 0 {
                throw POSIXErrorCode(rawValue: errno).map {
                    print($0.rawValue)
                    return Error.posixError($0)
                    } ?? Error.unknown
            }
            
            let data = Array<Int8>(repeating: 0, count: requiredSize)
            let result = data.withUnsafeBufferPointer() { dataBuffer -> Int32 in
                return Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress), UInt32(keys.count), UnsafeMutableRawPointer(mutating: dataBuffer.baseAddress), &requiredSize, nil, 0)
            }
            
            if result != 0 {
                throw POSIXErrorCode(rawValue: errno).map { Error.posixError($0) } ?? Error.unknown
            }
            
            return data
        }
    }
    
    static func keysForName(_ name: String) throws -> [Int32] {
        var keysBufferSize = Int(CTL_MAXNAME)
        var keysBuffer = Array<Int32>(repeating: 0, count: keysBufferSize)
        
        try keysBuffer.withUnsafeMutableBufferPointer { (lbp: inout UnsafeMutableBufferPointer<Int32>) throws in
            try name.withCString { (nbp: UnsafePointer<Int8>) throws in
                guard sysctlnametomib(nbp, lbp.baseAddress, &keysBufferSize) == 0 else {
                    throw POSIXErrorCode(rawValue: errno).map { Error.posixError($0) } ?? Error.unknown
                }
            }
        }
        
        if keysBuffer.count > keysBufferSize {
            keysBuffer.removeSubrange(keysBufferSize..<keysBuffer.count)
        }
        
        return keysBuffer
    }
    
    static func valueOfType<T>(_ type: T.Type, forKeys keys: [Int32]) throws -> T {
        let buffer = try dataForKeys(keys)
        if buffer.count != MemoryLayout<T>.size {
            throw Error.invalidSize
        }
        return try buffer.withUnsafeBufferPointer() { bufferPtr throws -> T in
            guard let baseAddress = bufferPtr.baseAddress else { throw Error.unknown }
            return baseAddress.withMemoryRebound(to: T.self, capacity: 1) { $0.pointee }
        }
    }
    
    static func valueOfType<T>(_ type: T.Type, forKeys keys: Int32...) throws -> T {
        return try valueOfType(type, forKeys: keys)
    }
    
    static func valueOfType<T>(_ type: T.Type, forName name: String) throws -> T {
        return try valueOfType(type, forKeys: keysForName(name))
    }
    
    static func stringForKeys(_ keys: [Int32]) throws -> String {
        let optionalString = try dataForKeys(keys).withUnsafeBufferPointer() { dataPointer -> String? in
            dataPointer.baseAddress.flatMap { String(validatingUTF8: $0) }
        }
        guard let s = optionalString else {
            throw Error.malformedUTF8
        }
        return s
    }
    
    static func stringForKeys(_ keys: Int32...) throws -> String {
        return try stringForKeys(keys)
    }
    
    static func stringForName(_ name: String) throws -> String {
        return try stringForKeys(keysForName(name))
    }
    
    static var hostName: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_HOSTNAME]) }
    
    static var machine: String {
        #if os(iOS) && !arch(x86_64) && !arch(i386)
        return try! Sysctl.stringForKeys([CTL_HW, HW_MODEL])
        #else
        return try! Sysctl.stringForKeys([CTL_HW, HW_MACHINE])
        #endif
    }
    
    static var model: String {
        #if os(iOS) && !arch(x86_64) && !arch(i386)
        return try! Sysctl.stringForKeys([CTL_HW, HW_MACHINE])
        #else
        return try! Sysctl.stringForKeys([CTL_HW, HW_MODEL])
        #endif
    }
    
    static var activeCPUs: Int32 { return try! Sysctl.valueOfType(Int32.self, forKeys: [CTL_HW, HW_AVAILCPU]) }
    
    static var osRelease: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_OSRELEASE]) }
    
    static var osType: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_OSTYPE]) }
    
    static var osVersion: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_OSVERSION]) }
    
    static var version: String { return try! Sysctl.stringForKeys([CTL_KERN, KERN_VERSION]) }
    
    #if os(macOS)
    static var osRev: Int32 { return try! Sysctl.valueOfType(Int32.self, forKeys: [CTL_KERN, KERN_OSREV]) }
    
    static var cpuFreq: Int64 { return try! Sysctl.valueOfType(Int64.self, forName: "hw.cpufrequency") }
    
    static var memSize: UInt64 { return try! Sysctl.valueOfType(UInt64.self, forKeys: [CTL_HW, HW_MEMSIZE]) }
    #endif
}
