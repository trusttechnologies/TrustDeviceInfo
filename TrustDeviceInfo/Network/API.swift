//
//  API.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/22/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

import Alamofire
import AlamofireObjectMapper
import ObjectMapper

// MARK: - StatusCode Enum
enum StatusCode: Int {
    case invalidToken = 401
}

// MARK: - API Struct
enum API {
    static let baseURL = "http://api.trust.lat"
    static let apiVersion = "/api/v1"
}

extension API {
    static func handle(httpResponse: HTTPURLResponse?) {
        guard
            let httpResponse = httpResponse,
            let statusCode = StatusCode(rawValue: httpResponse.statusCode) else {
                return
        }        
        switch statusCode {
        case .invalidToken: break
        }
    }

    static func call<T: Mappable>(responseDataType: T.Type, resource: APIRouter, onResponse: CompletionHandler = nil, onSuccess: SuccessHandler<T> = nil, onFailure: CompletionHandler = nil) {
        request(resource).responseObject {
            (response: DataResponse<T>) in
            
            print("API.call() Response: \(response)")
            
            if let onResponse = onResponse {
                onResponse()
            }
            
            switch (response.result) {
            case .success(let response):
                guard let onSuccess = onSuccess else {
                    return
                }
                
                onSuccess(response)
            case .failure(_):
                guard let onFailure = onFailure else {
                    return
                }
                
                onFailure()
            }
        }
    }

    static func callAsJSON(resource: APIRouter, onResponse: SuccessHandler<DataResponse<Any>> = nil, onSuccess: SuccessHandler<Any> = nil, onFailure: CompletionHandler = nil) {
        request(resource).responseJSON {
            (response: DataResponse<Any>) in
            
            print("API.callAsJSON() Response as JSON: \(response)")
            
            if let onResponse = onResponse {
                onResponse(response)
            }
            
            switch (response.result) {
            case .success(let responseData):
                guard let onSuccess = onSuccess else {
                    return
                }
                
                onSuccess(responseData)
            case .failure(_):
                guard let onFailure = onFailure else {
                    return
                }
                
                onFailure()
            }
        }
    }
}
