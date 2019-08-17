//
//  Identify.swift
//  TrustDeviceInfo
//
//  Created by Kevin Torres on 8/16/19.
//  Copyright © 2019 Jumpitt Labs. All rights reserved.
//

import Alamofire
import CoreTelephony

// MARK: - SIMInfoDelegate
public protocol SIMInfoDelegate: AnyObject {
    func onCarrierInfoHasChanged(carrier: String)
}

// MARK: - TrustIDDelegate
public protocol TrustDeviceInfoDelegate: AnyObject { //Implement in class
    func onClientCredentialsSaved(savedClientCredentials: ClientCredentials)
    func onTrustIDSaved(savedTrustID: String)
    func onRegisterFirebaseTokenSuccess(responseData: RegisterFirebaseTokenResponse)
    func onSendDeviceInfoResponse(status: ResponseStatus)
}

// MARK: - Identify
public class Identify {
    private var sendDeviceInfoOnEnabled: Bool = false
    
    private var enable = false {
        didSet {
            if enable && !oldValue {
                setCarrierUpdateNotifier()
                
                guard sendDeviceInfoOnEnabled else { return }
                
                createClientCredentials()
            } else if !enable && oldValue {
                disableCarrierUpdateNotifier()
            }
        }
    }
    
    // MARK: - Private instance
    private static var trustDeviceInfo: Identify = {
        return Identify()
    }()
    
    // MARK: - Shared instance
    public static var shared: Identify {
        return trustDeviceInfo
    }
    
    // MARK: - Shared keychain values
    static var accessGroup: String {
        return UserDefaults.standard.string(forKey: "accessGroup") ?? ""
    }
    
    static var serviceName: String {
        return UserDefaults.standard.string(forKey: "serviceName") ?? Bundle.main.bundleIdentifier ?? "SwiftKeychainWrapper"
    }
    
    // MARK: - ClientCredentialsManager
    private lazy var clientCredentialsManager: ClientCredentialsManagerProtocol = {
        let clientCredentialsDataManager = ClientCredentialsManager(serviceName: Identify.serviceName, accessGroup: Identify.accessGroup)
        
        clientCredentialsDataManager.managerOutput = self
        return clientCredentialsDataManager
    }()
    
    // MARK: - TrustIDManager
    private lazy var trustIDManager: TrustIDManagerProtocol = {
        let trustIDManager = TrustIDManager(serviceName: Identify.serviceName, accessGroup: Identify.accessGroup)
        
        trustIDManager.managerOutput = self
        return trustIDManager
    }()
    
    // MARK: - APIManager
    private lazy var apiManager: APIManagerProtocol = {
        let apiManager = APIManager()
        apiManager.managerOutput = self
        return apiManager
    }()
    
    // MARK: - NetworkInfo
    private lazy var networkInfo: CTTelephonyNetworkInfo = {
        let networkInfo = CTTelephonyNetworkInfo()
        return networkInfo
    }()
    
    // MARK: - Delegates
    public weak var simInfoDelegate: SIMInfoDelegate?
    public weak var trustDeviceInfoDelegate: TrustDeviceInfoDelegate?
    
    public var sendDeviceInfoCompletionHandler: ((ResponseStatus) -> Void)?
    
    // MARK: - Private Init
    private init() {}
    
    deinit {
        disable()
    }
}

// MARK: - Enable/Disable TrustDeviceInfo
extension Identify {
    public func enable(sendDeviceInfoOnEnabled: Bool = true) {
        self.sendDeviceInfoOnEnabled = sendDeviceInfoOnEnabled
        enable = true
    }
    
    public func disable() {
        enable = false
    }
}

// MARK: - Enable/Disable CarrierUpdateNotifier
extension Identify {
    private func setCarrierUpdateNotifier() {
        let updateNotifier: ((String) -> Void) = {
            carrier in
            
            DispatchQueue.main.async {
                [weak self] in
                
                guard let self = self else { return }
                
                self.sendDeviceInfo()
                
                guard let delegate = self.simInfoDelegate else { return }
                
                delegate.onCarrierInfoHasChanged(carrier: carrier)
            }
        }
        
        networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = updateNotifier
    }
    
    private func disableCarrierUpdateNotifier() {
        networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = nil
    }
}

// MARK: - getResponseStatus
extension Identify {
    private func getResponseStatus(response: HTTPURLResponse?) -> ResponseStatus {
        guard let statusCode = response?.statusCode else {
            return .error
        }
        
        switch statusCode {
        case 200:
            guard trustIDManager.hasTrustIDBeenSaved() else {
                return .created
            }
            return .noChanges
        case 201:
            return .updated
        default:
            return .error
        }
    }
}

// MARK: - Public Methods
extension Identify {
    public func set(serviceName: String, accessGroup: String) {
        UserDefaults.standard.set(serviceName, forKey: "serviceName")
        UserDefaults.standard.set(accessGroup, forKey: "accessGroup")
    }
    
    public func createClientCredentials (
        clientID: String = "adcc11078bee4ba2d7880a48c4bed02758a5f5328276b08fa14493306f1e9efb",
        clientSecret: String = "1f647aab37f4a7d7a0da408015437e7a963daca43da06a7789608c319c2930bd") {
        
        let parameters = ClientCredentialsParameters(clientID: clientID, clientSecret: clientSecret)
        
        apiManager.getClientCredentials(with: parameters)
    }
    
    public func sendDeviceInfo(identityInfo: IdentityInfoDataSource? = nil, completionHandler: ((ResponseStatus) -> Void)? = nil) {
        let parameters = DeviceInfoParameters(identityInfo: identityInfo, networkInfo: networkInfo)
        
        apiManager.sendDeviceInfo(with: parameters)
        
        sendDeviceInfoCompletionHandler = completionHandler
    }
    
    public func setAppState(dni: String, bundleID: String) {
        let parameters = AppStateParameters(dni: dni, bundleID: bundleID)
        
        apiManager.setAppState(with: parameters)
    }
    
    public func registerFirebaseToken(firebaseToken: String, bundleID: String) {
        let parameters = RegisterFirebaseTokenParameters(firebaseToken: firebaseToken, bundleID: bundleID)
        
        apiManager.registerFirebaseToken(with: parameters)
    }
    
    public func hasTrustIDBeenSaved() -> Bool {
        return trustIDManager.hasTrustIDBeenSaved()
    }
    
    public func getTrustID() -> String? {
        return trustIDManager.getTrustID()
    }
    
    public func deleteTrustID() -> Bool {
        return trustIDManager.removeTrustID()
    }
    
    public func getClientCredentials() -> ClientCredentials? {
        return clientCredentialsManager.getClientCredentials()
    }
}
// MARK: - Outputs Protocols
// MARK: - APIManagerOutputProtocol
extension Identify: APIManagerOutputProtocol {
    func onClientCredentialsResponse() {}
    
    func onClientCredentialsSuccess(responseData: ClientCredentials) {
        clientCredentialsManager.save(clientCredentials: responseData)
    }
    
    func onClientCredentialsFailure() {}
    
    func onSendDeviceInfoResponse(response: DataResponse<TrustID>) {
        let httpResponse = response.response
        
        trustDeviceInfoDelegate?.onSendDeviceInfoResponse(status: getResponseStatus(response: httpResponse))
        sendDeviceInfoCompletionHandler?(getResponseStatus(response: httpResponse))
    }
    
    func onSendDeviceInfoSuccess(responseData: TrustID) {
        guard responseData.status else {
            return
        }
        
        guard let trustID = responseData.trustID else {
            print("onSendDeviceInfoSuccess: No TrustID")
            return
        }
        
        print("onSendDeviceInfoSuccess TrustID: \(trustID)")
        trustIDManager.save(trustID: trustID)
    }
    
    func onSendDeviceInfoFailure() {}
    
    func onSetAppStateResponse() {}
    func onSetAppStateSuccess() {}
    func onSetAppStateFailure() {}
    
    func onRegisterFirebaseTokenResponse() {}
    
    func onRegisterFirebaseTokenSuccess(responseData: RegisterFirebaseTokenResponse) {
        trustDeviceInfoDelegate?.onRegisterFirebaseTokenSuccess(responseData: responseData)
    }
    
    func onRegisterFirebaseTokenFailure() {}
}

// MARK: - ClientCredentialsDataManagerOutputProtocol
extension Identify: ClientCredentialsManagerOutputProtocol {
    func onClientCredentialsSaved(savedClientCredentials: ClientCredentials) {
        trustDeviceInfoDelegate?.onClientCredentialsSaved(savedClientCredentials: savedClientCredentials)
        sendDeviceInfo()
    }
}

// MARK: - TrustIDManagerOutputProtocol
extension Identify: TrustIDManagerOutputProtocol {
    func onTrustIDSaved(savedTrustID: String) {
        trustDeviceInfoDelegate?.onTrustIDSaved(savedTrustID: savedTrustID)
    }
}
