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
    
    func sendDeviceInfo(with parameters: DeviceInfoParameters)
    func setAppState(with parameters: AppStateParameters)
}

// MARK: - APIManagerOutputProtocol
protocol APIManagerOutputProtocol: AnyObject {
    func onSendDeviceInfoResponse(response: DataResponse<Any>)
    func onSendDeviceInfoSuccess(response: Any)
    func onSendDeviceInfoFailure()
    
    func onSetAppStateResponse()
    func onSetAppStateSuccess()
    func onSetAppStateFailure()
}

class APIManager: APIManagerProtocol {
    weak var managerOutput: APIManagerOutputProtocol?

    func sendDeviceInfo(with parameters: DeviceInfoParameters) {
        API.callAsJSON(
            resource: .sendDeviceInfo(parameters: parameters),
            onResponse: {
                [weak self] response in
                guard let self = self else {return}
                self.managerOutput?.onSendDeviceInfoResponse(response: response)
            }, onSuccess: {
                [weak self] response in
                guard let self = self else {return}
                self.managerOutput?.onSendDeviceInfoSuccess(response: response)
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
                [weak self] _ in
                guard let self = self else {return}
                self.managerOutput?.onSetAppStateResponse()
            }, onSuccess: {
                [weak self] response in
                guard let self = self else {return}
                self.managerOutput?.onSetAppStateSuccess()
            }, onFailure: {
                [weak self] in
                guard let self = self else {return}
                self.managerOutput?.onSetAppStateFailure()
            }
        )
    }
}
