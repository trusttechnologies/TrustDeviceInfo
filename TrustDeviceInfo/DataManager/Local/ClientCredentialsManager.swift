//
//  ClientCredentialsDataManager.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/23/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

// MARK: - ClientCredentialsManagerProtocol
protocol ClientCredentialsManagerProtocol: AnyObject {
    var managerOutput: ClientCredentialsManagerOutputProtocol? {get set}
    
    func save(clientCredentials: ClientCredentials)
    func getClientCredentials() -> ClientCredentials?
    func deleteClientCredentials()
}

// MARK: - ClientCredentialsManagerOutputProtocol
protocol ClientCredentialsManagerOutputProtocol: AnyObject {
    func onClientCredentialsSaved(savedClientCredentials: ClientCredentials)
}

// MARK: - ClientCredentialsManager
class ClientCredentialsManager: ClientCredentialsManagerProtocol {
    weak var managerOutput: ClientCredentialsManagerOutputProtocol?
    
    var accessGroup: String
    var serviceName: String
    
    var keychain: KeychainWrapper {
        return KeychainWrapper(serviceName: serviceName, accessGroup: accessGroup)
    }
    
    init(serviceName: String, accessGroup: String) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }
    
    func save(clientCredentials: ClientCredentials) {
        guard
            let tokenType = clientCredentials.tokenType,
            let accessToken = clientCredentials.accessToken else {return}
        
        keychain.set(tokenType, forKey: "tokenType")
        keychain.set(accessToken, forKey: "accessToken")
        
        managerOutput?.onClientCredentialsSaved(savedClientCredentials: clientCredentials)
    }
    
    func getClientCredentials() -> ClientCredentials? {
        guard
            let tokenType = keychain.string(forKey: "tokenType"),
            let accessToken = keychain.string(forKey: "accessToken") else { return nil }
        
        let clientCredentials = ClientCredentials()
        
        clientCredentials.tokenType = tokenType
        clientCredentials.accessToken = accessToken
        
        return clientCredentials
    }
    
    func deleteClientCredentials() {
        keychain.removeObject(forKey: "accessToken")
        keychain.removeObject(forKey: "tokenType")
//        keychain.remove(key: "accessToken")
//        keychain.remove(key: "tokenType")
    }
}
