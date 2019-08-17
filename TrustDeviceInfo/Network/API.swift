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

// MARK: - ResponseStatus Enum
public enum ResponseStatus: String {
    case created = "TrustID Creado"
    case noChanges = "No hay cambios"
    case updated = "Datos actualizados"
    case error = "Ha ocurrido un error en el envío de datos"
}

// MARK: - StatusCode Enum
enum StatusCode: Int {
    case invalidToken = 401
}

// MARK: - API class
class API {
    static let baseURL = "https://api.trust.lat"
    static let clientCredentialsBaseURL = "https://atenea.trust.lat"
    static let apiVersion = "/api/v1"
}

extension API {
    // MARK: - handle(httpResponse)
    static func handle(httpResponse: HTTPURLResponse?, onExpiredAuthToken: CompletionHandler) {
        guard let httpResponse = httpResponse else {return}
        
        print("handle() httpResponse.statusCode: \(httpResponse.statusCode)")
        
        guard let statusCode = StatusCode(rawValue: httpResponse.statusCode) else {return}
        
        print("handle() statusCode: \(statusCode)")
        
        switch statusCode {
        case .invalidToken:
            guard let onExpiredAuthToken = onExpiredAuthToken else {return}
            onExpiredAuthToken()
        }
    }
    
    // MARK: - call<T: Mappable>(onResponse: CompletionHandler), onResponse without response data
    static func call<T: Mappable>(responseDataType: T.Type, resource: APIRouter, onResponse: CompletionHandler = nil, onSuccess: SuccessHandler<T> = nil, onFailure: CompletionHandler = nil) {
        request(resource).responseObject {
            (response: DataResponse<T>) in
            handle(httpResponse: response.response) {
                let parameters = ClientCredentialsParameters(
                    clientID: "adcc11078bee4ba2d7880a48c4bed02758a5f5328276b08fa14493306f1e9efb",
                    clientSecret: "1f647aab37f4a7d7a0da408015437e7a963daca43da06a7789608c319c2930bd"
                )
                
                call(
                    responseDataType: ClientCredentials.self,
                    resource: .clientCredentials(parameters: parameters),
                    onResponse: {},
                    onSuccess: {
                        responseData in
                        
                        let serviceName = Identify.serviceName
                        let accessGroup = Identify.accessGroup
                        
                        let clientCredentialsManager = ClientCredentialsManager(serviceName: serviceName, accessGroup: accessGroup)
                        
                        clientCredentialsManager.save(clientCredentials: responseData)
                        call(
                            responseDataType: responseDataType,
                            resource: resource,
                            onResponse: onResponse,
                            onSuccess: onSuccess,
                            onFailure: onFailure
                        )
                }
                )
            }
            
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
    
    // MARK: - call<T: Mappable>(onResponse: SuccessHandler<DataResponse<T>>), onResponse with response data
    static func call<T: Mappable>(responseDataType: T.Type, resource: APIRouter, onResponse: SuccessHandler<DataResponse<T>> = nil, onSuccess: SuccessHandler<T> = nil, onFailure: CompletionHandler = nil) {
        request(resource).responseObject {
            (response: DataResponse<T>) in
            handle(httpResponse: response.response) {
                let parameters = ClientCredentialsParameters(
                    clientID: "adcc11078bee4ba2d7880a48c4bed02758a5f5328276b08fa14493306f1e9efb",
                    clientSecret: "1f647aab37f4a7d7a0da408015437e7a963daca43da06a7789608c319c2930bd"
                )
                
                call(
                    responseDataType: ClientCredentials.self,
                    resource: .clientCredentials(parameters: parameters),
                    onResponse: {},
                    onSuccess: {
                        responseData in
                        
                        let serviceName = Identify.serviceName
                        let accessGroup = Identify.accessGroup
                        
                        let clientCredentialsManager = ClientCredentialsManager(serviceName: serviceName, accessGroup: accessGroup)
                        
                        clientCredentialsManager.save(clientCredentials: responseData)
                        
                        call(
                            responseDataType: responseDataType,
                            resource: resource,
                            onResponse: onResponse,
                            onSuccess: onSuccess,
                            onFailure: onFailure
                        )
                }
                )
            }
            
            if let onResponse = onResponse {
                onResponse(response)
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
    
    // MARK: - callAsJSON(onResponse: CompletionHandler), onResponse without response data
    static func callAsJSON(resource: APIRouter, onResponse: CompletionHandler = nil, onSuccess: SuccessHandler<Any> = nil, onFailure: CompletionHandler = nil) {
        request(resource).responseJSON {
            (response: DataResponse<Any>) in
            
            print("API.callAsJSON() Response as JSON: \(response)")
            
            handle(httpResponse: response.response) {
                let parameters = ClientCredentialsParameters(
                    clientID: "adcc11078bee4ba2d7880a48c4bed02758a5f5328276b08fa14493306f1e9efb",
                    clientSecret: "1f647aab37f4a7d7a0da408015437e7a963daca43da06a7789608c319c2930bd"
                )
                
                call(
                    responseDataType: ClientCredentials.self,
                    resource: .clientCredentials(parameters: parameters),
                    onResponse: {},
                    onSuccess: {
                        responseData in
                        
                        let serviceName = Identify.serviceName
                        let accessGroup = Identify.accessGroup
                        
                        let clientCredentialsManager = ClientCredentialsManager(serviceName: serviceName, accessGroup: accessGroup)
                        
                        clientCredentialsManager.save(clientCredentials: responseData)
                        
                        callAsJSON(
                            resource: resource,
                            onResponse: onResponse,
                            onSuccess: onSuccess,
                            onFailure: onFailure
                        )
                }
                )
            }
            
            if let onResponse = onResponse {
                onResponse()
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
