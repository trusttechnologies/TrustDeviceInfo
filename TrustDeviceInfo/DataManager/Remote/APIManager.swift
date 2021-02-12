//
//  APIManager.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/22/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

import Alamofire

// FIXME: - Improve APIManager by separating into different managers.
/*
 All in remote:
 - ClientCredentialsManager
 - DeviceInfoManager
 - AppStateManager
 - FirebaseTokenManager
 */

// MARK: - APIManagerProtocol
protocol APIManagerProtocol: AnyObject {
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
    
    func onSendDeviceInfoResponse(response: AFDataResponse<TrustID>)
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
final class APIManager {
    weak var managerOutput: APIManagerOutputProtocol?
}

// MARK: - APIManagerProtocol
extension APIManager: APIManagerProtocol {
    func getClientCredentials(with parameters: ClientCredentialsParameters) {
        API.call(
            resource: .clientCredentials(parameters: parameters),
            onResponse: {
                self.managerOutput?.onClientCredentialsResponse()
            }, onSuccess: { (responseData: ClientCredentials) in
                self.managerOutput?.onClientCredentialsSuccess(responseData: responseData)
            }, onFailure: {
                self.managerOutput?.onClientCredentialsFailure()
            }
        )
    }
    
    func sendDeviceInfo(with parameters: DeviceInfoParameters) {
        API.call(
            resource: .sendDeviceInfo(parameters: parameters),
            onResponseWithData: { response in
                self.managerOutput?.onSendDeviceInfoResponse(response: response)
            }, onSuccess: { (responseData: TrustID) in
                self.managerOutput?.onSendDeviceInfoSuccess(responseData: responseData)
            }, onFailure: {
                self.managerOutput?.onSendDeviceInfoFailure()
            }
        )
    }
    
    func setAppState(with parameters: AppStateParameters) {
        API.callAsJSON(
            resource: .setAppState(parameters: parameters),
            onResponse: {
                self.managerOutput?.onSetAppStateResponse()
            }, onSuccess: { _ in
                self.managerOutput?.onSetAppStateSuccess()
            }, onFailure: {
                self.managerOutput?.onSetAppStateFailure()
            }
        )
    }
    
    func registerFirebaseToken(with parameters: RegisterFirebaseTokenParameters) {
        API.call(
            resource: .registerFirebaseToken(parameters: parameters),
            onResponse: {
                self.managerOutput?.onRegisterFirebaseTokenResponse()
            }, onSuccess: { (responseData: RegisterFirebaseTokenResponse) in
                self.managerOutput?.onRegisterFirebaseTokenSuccess(responseData: responseData)
            }, onFailure: {
                self.managerOutput?.onRegisterFirebaseTokenFailure()
            }
        )
    }
}
