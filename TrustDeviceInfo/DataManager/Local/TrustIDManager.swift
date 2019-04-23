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
    func removeTrustID()
}

// MARK: - TrustIDManagerOutputProtocol
protocol TrustIDManagerOutputProtocol: AnyObject {
    func onTrustIDSaved()
}

// MARK: - TrustIDManager
class TrustIDManager: TrustIDManagerProtocol {
    private let trustIDKey = "trustid"
    private let oldDeviceKey = Sysctl.model
    private let deviceKey = "\(Sysctl.model)\(DiskStatus.totalDiskSpace)"
    
    weak var managerOutput: TrustIDManagerOutputProtocol?
    
    func hasTrustIDBeenSaved() -> Bool {
        return getTrustID() != nil
    }
    
    func getTrustID() -> String? {
        return KeychainWrapper.standard.string(forKey: deviceKey)
    }
    
    func save(trustID: String) {
        if !hasTrustIDBeenSaved() {
            if let savedTrustID = KeychainWrapper.standard.string(forKey: trustIDKey) {
                KeychainWrapper.standard.set(savedTrustID, forKey: deviceKey)
                KeychainWrapper.standard.removeObject(forKey: trustIDKey)
            } else if let savedTrustID = KeychainWrapper.standard.string(forKey: oldDeviceKey) {
                KeychainWrapper.standard.set(savedTrustID, forKey: deviceKey)
                KeychainWrapper.standard.removeObject(forKey: oldDeviceKey)
            } else {
                KeychainWrapper.standard.set(trustID, forKey: deviceKey)
            }
        }

        managerOutput?.onTrustIDSaved()
    }
    
    func removeTrustID() {
        KeychainWrapper.standard.removeObject(forKey: deviceKey)
    }
}