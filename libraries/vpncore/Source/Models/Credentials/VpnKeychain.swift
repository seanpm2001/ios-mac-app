//
//  VpnKeychain.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import KeychainAccess
import Logging
import VPNShared

public typealias VpnDowngradeInfo = (from: VpnCredentials, to: VpnCredentials)

public protocol VpnKeychainProtocol {
    
    static var vpnCredentialsChanged: Notification.Name { get }
    static var vpnPlanChanged: Notification.Name { get }
    static var vpnUserDelinquent: Notification.Name { get }

    func fetch() throws -> VpnCredentials
    func fetchCached() throws -> CachedVpnCredentials
    func fetchOpenVpnPassword() throws -> Data
    func store(vpnCredentials: VpnCredentials)
    func getServerCertificate() throws -> SecCertificate
    func storeServerCertificate() throws
    func store(wireguardConfiguration: Data) throws -> Data
    func fetchWireguardConfigurationReference() throws -> Data
    func fetchWireguardConfiguration() throws -> String?
    func clear()
}

extension VpnKeychainProtocol {
    var userIsLoggedIn: Bool {
        (try? fetch()) != nil
    }
}

public protocol VpnKeychainFactory {
    func makeVpnKeychain() -> VpnKeychainProtocol
}

internal enum KeychainEnvironment {
    static var secItemAdd = SecItemAdd
    static var secItemDelete = SecItemDelete
    static var secItemCopyMatching = SecItemCopyMatching
}

public class VpnKeychain: VpnKeychainProtocol {
    
    private struct StorageKey {
        static let vpnCredentials = "vpnCredentials"
        static let openVpnPassword_old = "openVpnPassword"
        static let vpnServerPassword = "ProtonVPN-Server-Password"
        static let serverCertificate = "ProtonVPN_ike_root"
        static let wireguardSettings = "ProtonVPN_wg_settings"
    }
    
    private let appKeychain = Keychain(service: KeychainConstants.appKeychain).accessibility(.afterFirstUnlockThisDeviceOnly)
    
    public static let vpnCredentialsChanged = Notification.Name("VpnKeychainCredentialsChanged")
    public static let vpnPlanChanged = Notification.Name("VpnKeychainPlanChanged")
    public static let vpnUserDelinquent = Notification.Name("VpnUserDelinquent")

    private let log = Logger.instance(withCategory: .keychain)
    
    public init() {}

    private var cached: CachedVpnCredentials?
    
    public func fetch() throws -> VpnCredentials {
        do {
            if let data = try appKeychain.getData(StorageKey.vpnCredentials) {
                if let unarchivedObject = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [VpnCredentials.self, NSString.self, NSData.self, NSNumber.self], from: data)),
                   let vpnCredentials = unarchivedObject as? VpnCredentials {
                    cached = CachedVpnCredentials(credentials: vpnCredentials)
                    return vpnCredentials
                }
            }
        } catch let error {
            log.error("Keychain (vpn) read error", metadata: ["error": "\(error)"])
        }
        
        let error = ProtonVpnErrorConst.vpnCredentialsMissing
        log.error("Error while fetching open vpn credentials from the keychain", metadata: ["error": "\(error)"])
        throw error
    }

    public func fetchCached() throws -> CachedVpnCredentials {
        return try cached ?? CachedVpnCredentials(credentials: fetch())
    }
    
    public func fetchOpenVpnPassword() throws -> Data {
        do {
            let password = try getPasswordReference(forKey: StorageKey.vpnServerPassword)
            return password
        } catch let error {
            log.error("Error while fetching open vpn password from the keychain", metadata: ["error": "\(error)"])
            throw ProtonVpnErrorConst.vpnCredentialsMissing
        }
    }
    
    public func store(vpnCredentials: VpnCredentials) {
        if let currentCredentials = try? fetch() {
            DispatchQueue.main.async {
                let downgradeInfo = VpnDowngradeInfo(currentCredentials, vpnCredentials)
                if !currentCredentials.isDelinquent, vpnCredentials.isDelinquent {
                    NotificationCenter.default.post(name: VpnKeychain.vpnUserDelinquent, object: downgradeInfo)
                }

                if currentCredentials.maxTier != vpnCredentials.maxTier {
                    NotificationCenter.default.post(name: VpnKeychain.vpnPlanChanged, object: downgradeInfo)
                }
            }
        }

        do {
            try appKeychain.set(NSKeyedArchiver.archivedData(withRootObject: vpnCredentials, requiringSecureCoding: true), key: StorageKey.vpnCredentials)
            cached = CachedVpnCredentials(credentials: vpnCredentials)
        } catch let error {
            log.error("Keychain (vpn) write error", metadata: ["error": "\(error)"])
        }
        
        do {
            try setPassword(vpnCredentials.password, forKey: StorageKey.vpnServerPassword)
        } catch let error {
            log.error("Error occurred during OpenVPN password storage", metadata: ["error": "\(error)"])
        }
        
        DispatchQueue.main.async { NotificationCenter.default.post(name: VpnKeychain.vpnCredentialsChanged, object: vpnCredentials) }
    }
    
    public func clear() {
        cached = nil
        appKeychain[data: StorageKey.vpnCredentials] = nil
        deleteServerCertificate()
        do {
            try clearPassword(forKey: StorageKey.vpnServerPassword)
            try clearPassword(forKey: StorageKey.wireguardSettings)
            DispatchQueue.main.async { NotificationCenter.default.post(name: VpnKeychain.vpnCredentialsChanged, object: nil) }
        } catch { }
    }
    
    // Password is set and retrieved without using the library because NEVPNProtocol reuquires it to be
    // a "persistent keychain reference to a keychain item containing the password component of the
    // tunneling protocol authentication credential".
    public func getPasswordReference(forKey key: String) throws -> Data {
        var query = formBaseQuery(forKey: key)
        query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
        query[kSecReturnPersistentRef as AnyHashable] = kCFBooleanTrue
        
        var secItem: AnyObject?
        let result = KeychainEnvironment.secItemCopyMatching(query as CFDictionary, &secItem)
        if result != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
        
        if let item = secItem as? Data {
            return item
        } else {
            throw ProtonVpnErrorConst.vpnCredentialsMissing
        }
    }

    private func setPasswordData(_ data: Data, forKey key: String) throws {
        do {
            var query = formBaseQuery(forKey: key)
            query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
            query[kSecReturnAttributes as AnyHashable] = kCFBooleanTrue
            query[kSecReturnData as AnyHashable] = kCFBooleanTrue

            var secItem: AnyObject?
            let result = KeychainEnvironment.secItemCopyMatching(query as CFDictionary, &secItem)
            if result != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
            }

            // If current item is the same as the one we want to write, just skip it
            guard let secItemDict = secItem as? [String: AnyObject],
                let oldPasswordData = secItemDict[kSecValueData as String] as? Data,
                  data == oldPasswordData else {
                throw NSError(domain: NSOSStatusErrorDomain, code: -1, userInfo: nil)
            }
        } catch {
            do {
                try clearPassword(forKey: key)
            } catch { }

            var query = formBaseQuery(forKey: key)
            query[kSecValueData as AnyHashable] = data

            let result = KeychainEnvironment.secItemAdd(query as CFDictionary, nil)
            if result != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
            }
        }
    }
    
    public func setPassword(_ password: String, forKey key: String) throws {
        try setPasswordData(password.data(using: .utf8)!, forKey: key)
    }

    private func clearPassword(forKey key: String) throws {
        let query = formBaseQuery(forKey: key)
        
        let result = KeychainEnvironment.secItemDelete(query as CFDictionary)
        if result != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
    }
    
    private func formBaseQuery(forKey key: String) -> [AnyHashable: Any] {
        return [
            kSecClass as AnyHashable: kSecClassGenericPassword,
            kSecAttrGeneric as AnyHashable: key,
            kSecAttrAccount as AnyHashable: key,
            kSecAttrService as AnyHashable: key,
            kSecAttrAccessible as AnyHashable: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as [AnyHashable: Any]
    }
    
    // MARK: - Certificates
    
    public func getServerCertificate() throws -> SecCertificate {
        let query: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                    kSecAttrLabel as String: StorageKey.serverCertificate,
                                    kSecReturnRef as String: kCFBooleanTrue as Any]
        var item: CFTypeRef?
        let result = KeychainEnvironment.secItemCopyMatching(query as CFDictionary, &item)
        guard result == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }

        return item as! SecCertificate
    }
    
    public func storeServerCertificate() throws {
        let certificateFile = Bundle.main.path(forResource: StorageKey.serverCertificate, ofType: "der")!
        let certificateData = NSData(contentsOfFile: certificateFile)!
        let certificate = SecCertificateCreateWithData(nil, certificateData)!
        
        let query: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                    kSecValueRef as String: certificate,
                                    kSecAttrLabel as String: StorageKey.serverCertificate]
        
        let result = KeychainEnvironment.secItemAdd(query as CFDictionary, nil)
        guard result == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: nil)
        }
    }
    
    private func deleteServerCertificate() {
        let query: [String: Any] = [kSecClass as String: kSecClassCertificate,
                                    kSecAttrLabel as String: StorageKey.serverCertificate,
                                    kSecReturnRef as String: kCFBooleanTrue as Any]
        _ = KeychainEnvironment.secItemDelete(query as CFDictionary)
    }
    
    // MARK: - Wireguard
    
    public func store(wireguardConfiguration: Data) throws -> Data {
        try setPasswordData(wireguardConfiguration, forKey: StorageKey.wireguardSettings)
        return try fetchWireguardConfigurationReference()
    }
    
    public func fetchWireguardConfigurationReference() throws -> Data {
        return try getPasswordReference(forKey: StorageKey.wireguardSettings)
    }
    
    public func fetchWireguardConfiguration() throws -> String? {
        
        var query = formBaseQuery(forKey: StorageKey.wireguardSettings)
        query[kSecMatchLimit as AnyHashable] = kSecMatchLimitOne
        query[kSecValuePersistentRef as AnyHashable] = try fetchWireguardConfigurationReference()
        query[kSecReturnData as AnyHashable] = true
        
        var secItem: AnyObject?
        let result = KeychainEnvironment.secItemCopyMatching(query as CFDictionary, &secItem)
        if result != errSecSuccess {
            log.error("Keychain error", metadata: ["SecItemCopyMatching": "\(result)"])
            return nil
        }
        
        if let item = secItem as? Data {
            let config = String(data: item, encoding: String.Encoding.utf8)
            log.debug("Config read", metadata: ["config": "\(config ?? "-")"])
            return config
            
        } else {
            log.error("Keychain error: can't read data")
            return nil
        }
    }
}
