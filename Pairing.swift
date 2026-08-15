// Pairing.swift
// MendezDDI - Version: 1.0.0
// Changelog:
// v1.0.0 - Implementación básica de parser de Plist de pairing y persistencia segura en Keychain.

import Foundation
import Security

enum PairingError: Error, LocalizedError {
    case invalidPlistFormat
    case udidNotFound
    case keychainSaveFailed(status: OSStatus)
    case keychainLoadFailed(status: OSStatus)
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .invalidPlistFormat:
            return "Formato de Plist inválido o no es un diccionario."
        case .udidNotFound:
            return "No se pudo encontrar la clave 'UDID' o 'DeviceUDID' en el archivo de pairing."
        case .keychainSaveFailed(let status):
            return "Error al guardar en Keychain. Código: \(status)"
        case .keychainLoadFailed(let status):
            return "Error al cargar desde Keychain. Código: \(status)"
        case .itemNotFound:
            return "No se encontró el registro de pairing en el Keychain."
        }
    }
}

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
            throw PairingError.invalidPlistFormat
        }
        
        // Extracción del UDID o Identificador del dispositivo
        guard let udid = plist["UDID"] as? String ?? plist["DeviceUDID"] as? String else {
            throw PairingError.udidNotFound
        }
        
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
            throw PairingError.keychainSaveFailed(status: status)
        }
    }

    /// Recupera el registro guardado previamente
    func loadPairingRecord(for udid: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: udid,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status != errSecItemNotFound else {
            throw PairingError.itemNotFound
        }
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            throw PairingError.keychainLoadFailed(status: status)
        }
        return data
    }
}
