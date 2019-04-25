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

    func save(clientCredentials: ClientCredentials) {
        guard
            let tokenType = clientCredentials.tokenType,
            let accessToken = clientCredentials.accessToken else {return}

        KeychainWrapper.ClientCredentials.set(tokenType, forKey: .tokenType)
        KeychainWrapper.ClientCredentials.set(accessToken, forKey: .accessToken)

        managerOutput?.onClientCredentialsSaved(savedClientCredentials: clientCredentials)
    }

    func getClientCredentials() -> ClientCredentials? {
        guard
            let tokenType = KeychainWrapper.ClientCredentials.string(forKey: .tokenType),
            let accessToken = KeychainWrapper.ClientCredentials.string(forKey: .accessToken) else {return nil}
        
        let clientCredentials = ClientCredentials()
            
        clientCredentials.tokenType = tokenType
        clientCredentials.accessToken = accessToken
        
        return clientCredentials
    }

    func deleteClientCredentials() {
        KeychainWrapper.ClientCredentials.remove(forKey: .accessToken)
        KeychainWrapper.ClientCredentials.remove(forKey: .tokenType)
    }
}
