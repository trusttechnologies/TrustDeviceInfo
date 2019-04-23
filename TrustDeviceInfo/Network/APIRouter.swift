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
    case sendDeviceInfo(parameters: Parameterizable)
    case setAppState(parameters: Parameterizable)

    var path: String {
        switch self {
        case .sendDeviceInfo:
            return "/identification\(API.apiVersion)/device"
        case .setAppState:
            return "/company\(API.apiVersion)/app/state"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .sendDeviceInfo, .setAppState:
            return .post
        }
    }

    var parameters: Parameters {
        switch self {
        case .sendDeviceInfo(let parameters):
            return parameters.asParameters
        case .setAppState(let parameters):
            return parameters.asParameters
        }
    }

    func asURLRequest() throws -> URLRequest {
        defer {
            print("Parameters: \(parameters)")
        }
        
        let baseURLAsString = API.baseURL
        
        guard let url = URL(string: baseURLAsString) else {
            return URLRequest(url: URL(string: .empty)!)
        }
        
        var urlRequest = URLRequest(url: url.appendingPathComponent(path))
        
        urlRequest.httpMethod = method.rawValue
        
        switch self {
        case .sendDeviceInfo, .setAppState:
            return try JSONEncoding.default.encode(urlRequest, with: parameters)
        }
    }
}
