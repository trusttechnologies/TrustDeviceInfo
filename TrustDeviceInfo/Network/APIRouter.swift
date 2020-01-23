//
//  APIRouter.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/22/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

import Alamofire

// MARK: - APIRouter
enum APIRouter: URLRequestConvertible {
    case clientCredentials(parameters: Parameterizable)
    case sendDeviceInfo(parameters: Parameterizable)
    case setAppState(parameters: Parameterizable)
    case registerFirebaseToken(parameters: Parameterizable)
    
    var path: String {
        switch self {
        case .clientCredentials:
            return "/oauth/token/"
        case .sendDeviceInfo:
            return "/identification\(API.apiVersion)/device"
        case .setAppState:
            return "/company\(API.apiVersion)/app/state"
        case .registerFirebaseToken:
            return "/notifications/device/register"
        }
    }
//    var currentEnvironment = 

    var method: HTTPMethod {
        switch self {
        case .clientCredentials, .sendDeviceInfo, .setAppState, .registerFirebaseToken:
            return .post
        }
    }
    
    var parameters: Parameters {
        switch self {
        case .clientCredentials(let parameters):
            return parameters.asParameters
        case .sendDeviceInfo(let parameters):
            return parameters.asParameters
        case .setAppState(let parameters):
            return parameters.asParameters
        case .registerFirebaseToken(let parameters):
            return parameters.asParameters
        }
    }
    
    func asURLRequest() throws -> URLRequest {
        var baseURLAsString: String = .empty
        
        switch self {
        case .clientCredentials:
            if UserDefaults.standard.string(forKey: "currentEnvironment") == "prod" {
                baseURLAsString = API.clientCredentialsBaseURL
            } else {
                baseURLAsString = API.clientCredentialsBaseURLTest
            }
        case .sendDeviceInfo, .setAppState, .registerFirebaseToken:
            if UserDefaults.standard.string(forKey: "currentEnvironment") == "prod" {
                baseURLAsString = API.baseURL
            } else {
                baseURLAsString = API.baseURLTest
            }
        }
        
        guard let url = URL(string: baseURLAsString) else {
            return URLRequest(url: URL(string: .empty)!)
        }
        
        var urlRequest = URLRequest(url: url.appendingPathComponent(path))
        
        defer {
            print("urlRequest: \(urlRequest)")
            print("urlRequest.allHTTPHeaderFields: \(String(describing: urlRequest.allHTTPHeaderFields))")
            print("Parameters: \(parameters)")
        }
        
        urlRequest.httpMethod = method.rawValue
        
        switch self {
        case .sendDeviceInfo, .setAppState, .registerFirebaseToken:
            
            let serviceName = Identify.serviceName
            let accessGroup = Identify.accessGroup
            
            let clientCredentialsManager = ClientCredentialsManager(serviceName: serviceName, accessGroup: accessGroup)
            
            if
                let clientCredentials = clientCredentialsManager.getClientCredentials(),
                let tokenType = clientCredentials.tokenType,
                let accessToken = clientCredentials.accessToken {
                
                let authorizationHeaderValue = "\(tokenType) \(accessToken)"
                
                print(authorizationHeaderValue)
                
                urlRequest.addValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
            }
        default: break
        }
        
        switch self {
        case .clientCredentials, .sendDeviceInfo, .setAppState, .registerFirebaseToken:
            return try JSONEncoding.default.encode(urlRequest, with: parameters)
        }
    }
}
