//
//  TrustIDManager.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/22/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

// MARK: - TrustIDManagerProtocol
protocol TrustIDManagerProtocol: AnyObject {
    var managerOutput: TrustIDManagerOutputProtocol? {get set}
    
    func hasTrustIDBeenSaved() -> Bool
    func getTrustID() -> String?
    func save(trustID: String)
    func removeTrustID() -> Bool
}

// MARK: - TrustIDManagerOutputProtocol
protocol TrustIDManagerOutputProtocol: AnyObject {
    func onTrustIDSaved(savedTrustID: String)
}

// MARK: - TrustIDManager
class TrustIDManager: TrustIDManagerProtocol {
    private let oldTrustIDKey = "trustid"
    private let oldDeviceKey = Sysctl.model
    private let deviceKey = "\(Sysctl.model)\(DiskStatus.totalDiskSpace)"
    
    var serviceName: String
    var accessGroup: String
    
    var keychain: KeychainWrapper {
        return KeychainWrapper(serviceName: serviceName, accessGroup: accessGroup)
    }
    
    init(serviceName: String, accessGroup: String) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    weak var managerOutput: TrustIDManagerOutputProtocol?
    
    func hasTrustIDBeenSaved() -> Bool {
        return getTrustID() != nil
    }
    
    func getTrustID() -> String? {
        return keychain.string(forKey: deviceKey)
    }
    
    func save(trustID: String) {
        if !hasTrustIDBeenSaved() {
            if let savedTrustID = keychain.string(forKey: oldTrustIDKey) {
                keychain.set(savedTrustID, forKey: deviceKey)
                keychain.removeObject(forKey: oldTrustIDKey)
            } else if let savedTrustID = keychain.string(forKey: oldDeviceKey) {
                keychain.set(savedTrustID, forKey: deviceKey)
                keychain.removeObject(forKey: oldDeviceKey)
            } else {
                keychain.set(trustID, forKey: deviceKey)
            }
        } else {
            if let savedTrustID = getTrustID() {
                if !savedTrustID.elementsEqual(trustID) {
                    keychain.set(trustID, forKey: deviceKey)
                }
            }
        }
        
        if let trustID = getTrustID() {
            managerOutput?.onTrustIDSaved(savedTrustID: trustID)
        }
    }
    
    func removeTrustID() -> Bool {
        return keychain.removeObject(forKey: deviceKey)
    }
}
