//
//  APIManager.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/22/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

import Alamofire

// MARK: - APIManagerProtocol
protocol APIManagerProtocol: AnyObject {
    var managerOutput: APIManagerOutputProtocol? {get set}
    
    func getClientCredentials(with parameters: ClientCredentialsParameters)
    func sendDeviceInfo(with parameters: DeviceInfoParameters)
    func setAppState(with parameters: AppStateParameters)
    func registerFirebaseToken(with parameters: RegisterFirebaseTokenParameters)
}

// MARK: - APIManagerOutputProtocol
protocol APIManagerOutputProtocol: AnyObject {
    func onClientCredentialsResponse()
    func onClientCredentialsSuccess(responseData: ClientCredentials)
    func onClientCredentialsFailure()
    
    func onSendDeviceInfoResponse(response: DataResponse<TrustID>)
    func onSendDeviceInfoSuccess(responseData: TrustID)
    func onSendDeviceInfoFailure()
    
    func onSetAppStateResponse()
    func onSetAppStateSuccess()
    func onSetAppStateFailure()
    
    func onRegisterFirebaseTokenResponse()
    func onRegisterFirebaseTokenSuccess(responseData: RegisterFirebaseTokenResponse)
    func onRegisterFirebaseTokenFailure()
}

// MARK: - APIManager
class APIManager: APIManagerProtocol {
    weak var managerOutput: APIManagerOutputProtocol?
    
    func getClientCredentials(with parameters: ClientCredentialsParameters) {
        API.call(
            responseDataType: ClientCredentials.self,
            resource: .clientCredentials(parameters: parameters),
            onResponse: {
                [weak self] in
                guard let self = self else {return}
                self.managerOutput?.onClientCredentialsResponse()
            }, onSuccess: {
                [weak self] responseData in
                guard let self = self else {return}
                self.managerOutput?.onClientCredentialsSuccess(responseData: responseData)
            }, onFailure: {
                [weak self] in
                guard let self = self else {return}
                self.managerOutput?.onClientCredentialsFailure()
            }
        )
    }
    
    func sendDeviceInfo(with parameters: DeviceInfoParameters) {
        API.call(
            responseDataType: TrustID.self,
            resource: .sendDeviceInfo(parameters: parameters),
            onResponse: {
                [weak self] response in
                guard let self = self else {return}
                self.managerOutput?.onSendDeviceInfoResponse(response: response)
            }, onSuccess: {
                [weak self] responseData in
                guard let self = self else {return}
                self.managerOutput?.onSendDeviceInfoSuccess(responseData: responseData)
            }, onFailure: {
                [weak self] in
                guard let self = self else {return}
                self.managerOutput?.onSendDeviceInfoFailure()
            }
        )
    }
    
    func setAppState(with parameters: AppStateParameters) {
        API.callAsJSON(
            resource: .setAppState(parameters: parameters),
            onResponse: {
                [weak self] in
                guard let self = self else {return}
                self.managerOutput?.onSetAppStateResponse()
            }, onSuccess: {
                [weak self] _ in
                guard let self = self else {return}
                self.managerOutput?.onSetAppStateSuccess()
            }, onFailure: {
                [weak self] in
                guard let self = self else {return}
                self.managerOutput?.onSetAppStateFailure()
            }
        )
    }
    
    func registerFirebaseToken(with parameters: RegisterFirebaseTokenParameters) {
        API.call(
            responseDataType: RegisterFirebaseTokenResponse.self,
            resource: .registerFirebaseToken(parameters: parameters),
            onResponse: {
                [weak self] in
                guard let self = self else {return}
                self.managerOutput?.onRegisterFirebaseTokenResponse()
            }, onSuccess: {
                [weak self] responseData in
                guard let self = self else {return}
                self.managerOutput?.onRegisterFirebaseTokenSuccess(responseData: responseData)
            }, onFailure: {
                [weak self] in
                guard let self = self else {return}
                self.managerOutput?.onRegisterFirebaseTokenFailure()
            }
        )
    }
}
