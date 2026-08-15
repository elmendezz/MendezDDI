// Pairing.swift
// MendezDDI - Version: 1.0.0
// Changelog:
// v1.0.0 - Implementación básica de parser de Plist de pairing y persistencia segura en Keychain.

import Foundation
import Security

struct PairingRecord {
    let udid: String
    let rawData: Data
    var isValid: Bool
}

final class PairingManager {
    static let shared = PairingManager()
    private let keychainService = "com.mendez.ddi.pairing"

    private init() {}

    /// Procesa el contenido de un archivo .plist o .pairingfile
    func processPairingData(_ data: Data) throws -> PairingRecord {
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NSError(domain: "PairingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Formato de Plist inválido"])
        }
        
        // Extracción del UDID o Identificador del dispositivo
        let udid = plist["UDID"] as? String ?? plist["DeviceUDID"] as? String ?? "Unknown_UDID"
        
        let record = PairingRecord(udid: udid, rawData: data, isValid: true)
        try saveToKeychain(record: record)
        return record
    }

    /// Guarda el registro de pairing en el Keychain
    private func saveToKeychain(record: PairingRecord) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: record.udid,
            kSecAttrService as String: keychainService,
            kSecValueData as String: record.rawData
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Error al guardar credenciales en Keychain"])
        }
    }

    /// Recupera el registro guardado previamente
    func loadPairingRecord(for udid: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: udid,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
}
