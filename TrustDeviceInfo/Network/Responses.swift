//
//  Responses.swift
//  TrustDeviceInfo
//
//  Created by Diego Villouta Fredes on 4/24/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

import ObjectMapper

// MARK: - TrustID
public class TrustID: Mappable, CustomStringConvertible {
    var status = false
    var message: String?
    var trustID: String?
    
    public required convenience init?(map: Map) {
        self.init()
    }
    
    public func mapping(map: Map) {
        status <- map["status"]
        message <- map["message"]
        trustID <- map["trustid"]
    }
}

// MARK: - ClientCredentials
public class ClientCredentials: Mappable, CustomStringConvertible {
    public var accessToken: String?
    public var tokenType: String?
    
    public required convenience init?(map: Map) {
        self.init()
    }
    
    public func mapping(map: Map) {
        accessToken <- map["access_token"]
        tokenType <- map["token_type"]
    }
}

// MARK: - RegisterFirebaseTokenResponse
public class RegisterFirebaseTokenResponse: Mappable, CustomStringConvertible {
    var status: String?
    var code: Int?
    var message: String?
    
    public required convenience init?(map: Map) {
        self.init()
    }
    
    public func mapping(map: Map) {
        status <- map["status"]
        code <- map["code"]
        message <- map["message"]
    }
}
