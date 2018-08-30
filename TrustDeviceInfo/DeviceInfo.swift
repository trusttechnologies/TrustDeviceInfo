//
//  DeviceInfo.swift
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
    case advancedElectronicSignature = "Firma Electrónica Avanzada"
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
    
    var asParameters: Parameters {
        return [
            "source": [
                "trustid": DeviceInfo.shared.getTrustID(),
                "app_name": Bundle.main.displayName,
                "bundle_id": Bundle.main.bundleIdentifier,
                "system_name": device.systemName,
                "system_version": device.systemVersion
            ],
            "transaction": [
                "operation": transactionType?.rawValue ?? "",
                "method": authMethod?.rawValue ?? "",
                "timestamp": Date().toString(with: .yyyyMMddHHmmss)
            ],
            "geo": [
                "lat": latitude ?? "",
                "long": longitude ?? ""
            ]
        ]
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
public class DeviceInfo {
    
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
    public weak var onTrustIDDelegate: OnTrustIDDelegate?
    
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
                    
                    if let delegate = self.onTrustIDDelegate {
                        delegate.onTrustIDSaved()
                    }
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

protocol KeychainAttrRepresentable {
    var keychainAttrValue: CFString { get }
}

// MARK: - KeychainItemAccessibility
public enum KeychainItemAccessibility {
    /**
     The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
     
     After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute migrate to a new device when using encrypted backups.
     */
    @available(iOS 4, *)
    case afterFirstUnlock
    
    /**
     The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
     
     After the first unlock, the data remains accessible until the next restart. This is recommended for items that need to be accessed by background applications. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
     */
    @available(iOS 4, *)
    case afterFirstUnlockThisDeviceOnly
    
    /**
     The data in the keychain item can always be accessed regardless of whether the device is locked.
     
     This is not recommended for application use. Items with this attribute migrate to a new device when using encrypted backups.
     */
    @available(iOS 4, *)
    case always
    
    /**
     The data in the keychain can only be accessed when the device is unlocked. Only available if a passcode is set on the device.
     
     This is recommended for items that only need to be accessible while the application is in the foreground. Items with this attribute never migrate to a new device. After a backup is restored to a new device, these items are missing. No items can be stored in this class on devices without a passcode. Disabling the device passcode causes all items in this class to be deleted.
     */
    @available(iOS 8, *)
    case whenPasscodeSetThisDeviceOnly
    
    /**
     The data in the keychain item can always be accessed regardless of whether the device is locked.
     
     This is not recommended for application use. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
     */
    @available(iOS 4, *)
    case alwaysThisDeviceOnly
    
    /**
     The data in the keychain item can be accessed only while the device is unlocked by the user.
     
     This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute migrate to a new device when using encrypted backups.
     
     This is the default value for keychain items added without explicitly setting an accessibility constant.
     */
    @available(iOS 4, *)
    case whenUnlocked
    
    /**
     The data in the keychain item can be accessed only while the device is unlocked by the user.
     
     This is recommended for items that need to be accessible only while the application is in the foreground. Items with this attribute do not migrate to a new device. Thus, after restoring from a backup of a different device, these items will not be present.
     */
    @available(iOS 4, *)
    case whenUnlockedThisDeviceOnly
    
    static func accessibilityForAttributeValue(_ keychainAttrValue: CFString) -> KeychainItemAccessibility? {
        for (key, value) in keychainItemAccessibilityLookup {
            if value == keychainAttrValue {
                return key
            }
        }
        
        return nil
    }
}

private let keychainItemAccessibilityLookup: [KeychainItemAccessibility:CFString] = {
    var lookup: [KeychainItemAccessibility:CFString] = [
        .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlock,
        .afterFirstUnlockThisDeviceOnly: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        .always: kSecAttrAccessibleAlways,
        .whenPasscodeSetThisDeviceOnly: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .alwaysThisDeviceOnly : kSecAttrAccessibleAlwaysThisDeviceOnly,
        .whenUnlocked: kSecAttrAccessibleWhenUnlocked,
        .whenUnlockedThisDeviceOnly: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    
    return lookup
}()

extension KeychainItemAccessibility : KeychainAttrRepresentable {
    internal var keychainAttrValue: CFString {
        return keychainItemAccessibilityLookup[self]!
    }
}

private let SecMatchLimit: String! = kSecMatchLimit as String
private let SecReturnData: String! = kSecReturnData as String
private let SecReturnPersistentRef: String! = kSecReturnPersistentRef as String
private let SecValueData: String! = kSecValueData as String
private let SecAttrAccessible: String! = kSecAttrAccessible as String
private let SecClass: String! = kSecClass as String
private let SecAttrService: String! = kSecAttrService as String
private let SecAttrGeneric: String! = kSecAttrGeneric as String
private let SecAttrAccount: String! = kSecAttrAccount as String
private let SecAttrAccessGroup: String! = kSecAttrAccessGroup as String
private let SecReturnAttributes: String = kSecReturnAttributes as String

/// KeychainWrapper is a class to help make Keychain access in Swift more straightforward. It is designed to make accessing the Keychain services more like using NSUserDefaults, which is much more familiar to people.
open class KeychainWrapper {
    
    @available(*, deprecated: 2.2.1, message: "KeychainWrapper.defaultKeychainWrapper is deprecated, use KeychainWrapper.standard instead")
    public static let defaultKeychainWrapper = KeychainWrapper.standard
    
    /// Default keychain wrapper access
    public static let standard = KeychainWrapper()
    
    /// ServiceName is used for the kSecAttrService property to uniquely identify this keychain accessor. If no service name is specified, KeychainWrapper will default to using the bundleIdentifier.
    private (set) public var serviceName: String
    
    /// AccessGroup is used for the kSecAttrAccessGroup property to identify which Keychain Access Group this entry belongs to. This allows you to use the KeychainWrapper with shared keychain access between different applications.
    private (set) public var accessGroup: String?
    
    private static let defaultServiceName: String = {
        return Bundle.main.bundleIdentifier ?? "SwiftKeychainWrapper"
    }()
    
    private convenience init() {
        self.init(serviceName: KeychainWrapper.defaultServiceName)
    }
    
    /// Create a custom instance of KeychainWrapper with a custom Service Name and optional custom access group.
    ///
    /// - parameter serviceName: The ServiceName for this instance. Used to uniquely identify all keys stored using this keychain wrapper instance.
    /// - parameter accessGroup: Optional unique AccessGroup for this instance. Use a matching AccessGroup between applications to allow shared keychain access.
    public init(serviceName: String, accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    // MARK:- Public Methods
    
    /// Checks if keychain data exists for a specified key.
    ///
    /// - parameter forKey: The key to check for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - returns: True if a value exists for the key. False otherwise.
    open func hasValue(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        if let _ = data(forKey: key, withAccessibility: accessibility) {
            return true
        } else {
            return false
        }
    }
    
    open func accessibilityOfKey(_ key: String) -> KeychainItemAccessibility? {
        var keychainQueryDictionary = setupKeychainQueryDictionary(forKey: key)
        
        // Remove accessibility attribute
        keychainQueryDictionary.removeValue(forKey: SecAttrAccessible)
        
        // Limit search results to one
        keychainQueryDictionary[SecMatchLimit] = kSecMatchLimitOne
        
        // Specify we want SecAttrAccessible returned
        keychainQueryDictionary[SecReturnAttributes] = kCFBooleanTrue
        
        // Search
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)
        
        guard status == noErr, let resultsDictionary = result as? [String:AnyObject], let accessibilityAttrValue = resultsDictionary[SecAttrAccessible] as? String else {
            return nil
        }
        
        return KeychainItemAccessibility.accessibilityForAttributeValue(accessibilityAttrValue as CFString)
    }
    
    /// Get the keys of all keychain entries matching the current ServiceName and AccessGroup if one is set.
    open func allKeys() -> Set<String> {
        var keychainQueryDictionary: [String:Any] = [
            SecClass: kSecClassGenericPassword,
            SecAttrService: serviceName,
            SecReturnAttributes: kCFBooleanTrue,
            SecMatchLimit: kSecMatchLimitAll,
            ]
        
        if let accessGroup = self.accessGroup {
            keychainQueryDictionary[SecAttrAccessGroup] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)
        
        guard status == errSecSuccess else { return [] }
        
        var keys = Set<String>()
        if let results = result as? [[AnyHashable: Any]] {
            for attributes in results {
                if let accountData = attributes[SecAttrAccount] as? Data,
                    let account = String(data: accountData, encoding: String.Encoding.utf8) {
                    keys.insert(account)
                }
            }
        }
        return keys
    }
    
    // MARK: Public Getters
    
    open func integer(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Int? {
        guard let numberValue = object(forKey: key, withAccessibility: accessibility) as? NSNumber else {
            return nil
        }
        
        return numberValue.intValue
    }
    
    open func float(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Float? {
        guard let numberValue = object(forKey: key, withAccessibility: accessibility) as? NSNumber else {
            return nil
        }
        
        return numberValue.floatValue
    }
    
    open func double(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Double? {
        guard let numberValue = object(forKey: key, withAccessibility: accessibility) as? NSNumber else {
            return nil
        }
        
        return numberValue.doubleValue
    }
    
    open func bool(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool? {
        guard let numberValue = object(forKey: key, withAccessibility: accessibility) as? NSNumber else {
            return nil
        }
        
        return numberValue.boolValue
    }
    
    /// Returns a string value for a specified key.
    ///
    /// - parameter forKey: The key to lookup data for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - returns: The String associated with the key if it exists. If no data exists, or the data found cannot be encoded as a string, returns nil.
    open func string(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> String? {
        guard let keychainData = data(forKey: key, withAccessibility: accessibility) else {
            return nil
        }
        
        return String(data: keychainData, encoding: String.Encoding.utf8) as String?
    }
    
    /// Returns an object that conforms to NSCoding for a specified key.
    ///
    /// - parameter forKey: The key to lookup data for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - returns: The decoded object associated with the key if it exists. If no data exists, or the data found cannot be decoded, returns nil.
    open func object(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> NSCoding? {
        guard let keychainData = data(forKey: key, withAccessibility: accessibility) else {
            return nil
        }
        
        return NSKeyedUnarchiver.unarchiveObject(with: keychainData) as? NSCoding
    }
    
    
    /// Returns a Data object for a specified key.
    ///
    /// - parameter forKey: The key to lookup data for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - returns: The Data object associated with the key if it exists. If no data exists, returns nil.
    open func data(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Data? {
        var keychainQueryDictionary = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility)
        
        // Limit search results to one
        keychainQueryDictionary[SecMatchLimit] = kSecMatchLimitOne
        
        // Specify we want Data/CFData returned
        keychainQueryDictionary[SecReturnData] = kCFBooleanTrue
        
        // Search
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)
        
        return status == noErr ? result as? Data : nil
    }
    
    
    /// Returns a persistent data reference object for a specified key.
    ///
    /// - parameter forKey: The key to lookup data for.
    /// - parameter withAccessibility: Optional accessibility to use when retrieving the keychain item.
    /// - returns: The persistent data reference object associated with the key if it exists. If no data exists, returns nil.
    open func dataRef(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Data? {
        var keychainQueryDictionary = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility)
        
        // Limit search results to one
        keychainQueryDictionary[SecMatchLimit] = kSecMatchLimitOne
        
        // Specify we want persistent Data/CFData reference returned
        keychainQueryDictionary[SecReturnPersistentRef] = kCFBooleanTrue
        
        // Search
        var result: AnyObject?
        let status = SecItemCopyMatching(keychainQueryDictionary as CFDictionary, &result)
        
        return status == noErr ? result as? Data : nil
    }
    
    // MARK: Public Setters
    
    @discardableResult open func set(_ value: Int, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        return set(NSNumber(value: value), forKey: key, withAccessibility: accessibility)
    }
    
    @discardableResult open func set(_ value: Float, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        return set(NSNumber(value: value), forKey: key, withAccessibility: accessibility)
    }
    
    @discardableResult open func set(_ value: Double, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        return set(NSNumber(value: value), forKey: key, withAccessibility: accessibility)
    }
    
    @discardableResult open func set(_ value: Bool, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        return set(NSNumber(value: value), forKey: key, withAccessibility: accessibility)
    }
    
    /// Save a String value to the keychain associated with a specified key. If a String value already exists for the given key, the string will be overwritten with the new value.
    ///
    /// - parameter value: The String value to save.
    /// - parameter forKey: The key to save the String under.
    /// - parameter withAccessibility: Optional accessibility to use when setting the keychain item.
    /// - returns: True if the save was successful, false otherwise.
    @discardableResult open func set(_ value: String, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        if let data = value.data(using: .utf8) {
            return set(data, forKey: key, withAccessibility: accessibility)
        } else {
            return false
        }
    }
    
    /// Save an NSCoding compliant object to the keychain associated with a specified key. If an object already exists for the given key, the object will be overwritten with the new value.
    ///
    /// - parameter value: The NSCoding compliant object to save.
    /// - parameter forKey: The key to save the object under.
    /// - parameter withAccessibility: Optional accessibility to use when setting the keychain item.
    /// - returns: True if the save was successful, false otherwise.
    @discardableResult open func set(_ value: NSCoding, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: value)
        
        return set(data, forKey: key, withAccessibility: accessibility)
    }
    
    /// Save a Data object to the keychain associated with a specified key. If data already exists for the given key, the data will be overwritten with the new value.
    ///
    /// - parameter value: The Data object to save.
    /// - parameter forKey: The key to save the object under.
    /// - parameter withAccessibility: Optional accessibility to use when setting the keychain item.
    /// - returns: True if the save was successful, false otherwise.
    @discardableResult open func set(_ value: Data, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        var keychainQueryDictionary: [String:Any] = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility)
        
        keychainQueryDictionary[SecValueData] = value
        
        if let accessibility = accessibility {
            keychainQueryDictionary[SecAttrAccessible] = accessibility.keychainAttrValue
        } else {
            // Assign default protection - Protect the keychain entry so it's only valid when the device is unlocked
            keychainQueryDictionary[SecAttrAccessible] = KeychainItemAccessibility.whenUnlocked.keychainAttrValue
        }
        
        let status: OSStatus = SecItemAdd(keychainQueryDictionary as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else if status == errSecDuplicateItem {
            return update(value, forKey: key, withAccessibility: accessibility)
        } else {
            return false
        }
    }
    
    @available(*, deprecated: 2.2.1, message: "remove is deprecated, use removeObject instead")
    @discardableResult open func remove(key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        return removeObject(forKey: key, withAccessibility: accessibility)
    }
    
    /// Remove an object associated with a specified key. If re-using a key but with a different accessibility, first remove the previous key value using removeObjectForKey(:withAccessibility) using the same accessibilty it was saved with.
    ///
    /// - parameter forKey: The key value to remove data for.
    /// - parameter withAccessibility: Optional accessibility level to use when looking up the keychain item.
    /// - returns: True if successful, false otherwise.
    @discardableResult open func removeObject(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        let keychainQueryDictionary: [String:Any] = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility)
        
        // Delete
        let status: OSStatus = SecItemDelete(keychainQueryDictionary as CFDictionary)
        
        if status == errSecSuccess {
            return true
        } else {
            return false
        }
    }
    
    /// Remove all keychain data added through KeychainWrapper. This will only delete items matching the currnt ServiceName and AccessGroup if one is set.
    open func removeAllKeys() -> Bool {
        // Setup dictionary to access keychain and specify we are using a generic password (rather than a certificate, internet password, etc)
        var keychainQueryDictionary: [String:Any] = [SecClass:kSecClassGenericPassword]
        
        // Uniquely identify this keychain accessor
        keychainQueryDictionary[SecAttrService] = serviceName
        
        // Set the keychain access group if defined
        if let accessGroup = self.accessGroup {
            keychainQueryDictionary[SecAttrAccessGroup] = accessGroup
        }
        
        let status: OSStatus = SecItemDelete(keychainQueryDictionary as CFDictionary)
        
        if status == errSecSuccess {
            return true
        } else {
            return false
        }
    }
    
    /// Remove all keychain data, including data not added through keychain wrapper.
    ///
    /// - Warning: This may remove custom keychain entries you did not add via SwiftKeychainWrapper.
    ///
    open class func wipeKeychain() {
        deleteKeychainSecClass(kSecClassGenericPassword) // Generic password items
        deleteKeychainSecClass(kSecClassInternetPassword) // Internet password items
        deleteKeychainSecClass(kSecClassCertificate) // Certificate items
        deleteKeychainSecClass(kSecClassKey) // Cryptographic key items
        deleteKeychainSecClass(kSecClassIdentity) // Identity items
    }
    
    // MARK:- Private Methods
    
    /// Remove all items for a given Keychain Item Class
    ///
    ///
    @discardableResult private class func deleteKeychainSecClass(_ secClass: AnyObject) -> Bool {
        let query = [SecClass: secClass]
        let status: OSStatus = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            return true
        } else {
            return false
        }
    }
    
    /// Update existing data associated with a specified key name. The existing data will be overwritten by the new data.
    private func update(_ value: Data, forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> Bool {
        var keychainQueryDictionary: [String:Any] = setupKeychainQueryDictionary(forKey: key, withAccessibility: accessibility)
        let updateDictionary = [SecValueData:value]
        
        // on update, only set accessibility if passed in
        if let accessibility = accessibility {
            keychainQueryDictionary[SecAttrAccessible] = accessibility.keychainAttrValue
        }
        
        // Update
        let status: OSStatus = SecItemUpdate(keychainQueryDictionary as CFDictionary, updateDictionary as CFDictionary)
        
        if status == errSecSuccess {
            return true
        } else {
            return false
        }
    }
    
    /// Setup the keychain query dictionary used to access the keychain on iOS for a specified key name. Takes into account the Service Name and Access Group if one is set.
    ///
    /// - parameter forKey: The key this query is for
    /// - parameter withAccessibility: Optional accessibility to use when setting the keychain item. If none is provided, will default to .WhenUnlocked
    /// - returns: A dictionary with all the needed properties setup to access the keychain on iOS
    private func setupKeychainQueryDictionary(forKey key: String, withAccessibility accessibility: KeychainItemAccessibility? = nil) -> [String:Any] {
        // Setup default access as generic password (rather than a certificate, internet password, etc)
        var keychainQueryDictionary: [String:Any] = [SecClass:kSecClassGenericPassword]
        
        // Uniquely identify this keychain accessor
        keychainQueryDictionary[SecAttrService] = serviceName
        
        // Only set accessibiilty if its passed in, we don't want to default it here in case the user didn't want it set
        if let accessibility = accessibility {
            keychainQueryDictionary[SecAttrAccessible] = accessibility.keychainAttrValue
        }
        
        // Set the keychain access group if defined
        if let accessGroup = self.accessGroup {
            keychainQueryDictionary[SecAttrAccessGroup] = accessGroup
        }
        
        // Uniquely identify the account who will be accessing the keychain
        let encodedIdentifier: Data? = key.data(using: String.Encoding.utf8)
        
        keychainQueryDictionary[SecAttrGeneric] = encodedIdentifier
        
        keychainQueryDictionary[SecAttrAccount] = encodedIdentifier
        
        return keychainQueryDictionary
    }
}
