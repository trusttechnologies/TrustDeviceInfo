//
//  Responses.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/24/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

//import ObjectMapper

// MARK: - TrustID
public class TrustID: Codable, CustomStringConvertible {
    var status = false
    var message: String?
    var trustID: String?
    
    enum CodingKeys: String, CodingKey {
        case status = "status"
        case message = "message"
        case trustID = "trustid"
    }
}

// MARK: - ClientCredentials
public class ClientCredentials: Codable, CustomStringConvertible {
    public var accessToken: String?
    public var tokenType: String?
    
    /*enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }*/
}

// MARK: - RegisterFirebaseTokenResponse
public class RegisterFirebaseTokenResponse: Codable, CustomStringConvertible {
    var status: String?
    var code: Int?
    var message: String?
    
    /*enum CodingKeys: String, CodingKey {
        case status = "status"
        case code = "code"
        case message = "message"
    }*/
}
