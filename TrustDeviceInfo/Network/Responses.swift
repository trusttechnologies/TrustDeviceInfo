//
//  Responses.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/24/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

// MARK: - TrustID
public class TrustID: Decodable, CustomStringConvertible {
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
public class ClientCredentials: Decodable, CustomStringConvertible {
    public var accessToken: String?
    public var tokenType: String?
}

// MARK: - RegisterFirebaseTokenResponse
public class RegisterFirebaseTokenResponse: Decodable, CustomStringConvertible {
    var status: String?
    var code: Int?
    var message: String?
}
