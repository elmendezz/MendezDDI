// DDIManager.swift
// MendezDDI - Version: 1.0.1
// Changelog:
// v1.0.1 - Inclusión de import UIKit para resolver 'UIDevice' in scope.
// v1.0.0 - Gestor principal para conexiones Lockdown, detección de Developer Mode y verificación de DDI.

import Foundation

enum DDIStatus {
    case notMounted
    case mounted
    case unknown
}

enum LogType {
    case info
    case success
    case warning
    case error
}

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let message: String
    let type: LogType
    let timestamp: String

    init(message: String, type: LogType) {
        self.message = message
        self.type = type
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        self.timestamp = formatter.string(from: Date())
    }
}

final class DDIManager: ObservableObject {
    private let deviceCommunicator = DeviceCommunicator()

    @Published var isDeveloperModeEnabled: Bool = false
    @Published var ddiStatus: DDIStatus = .unknown
    @Published var deviceInfo: String = "No detectado"
    @Published var iosVersion: String = "Desconocida"
    @Published var detectedDevice: Device?
    @Published var logs: [LogEntry] = []
    @Published var mountProgress: Double = 0.0
    @Published var isMounting: Bool = false

    func log(_ message: String, type: LogType = .info) {
        DispatchQueue.main.async {
            self.logs.append(LogEntry(message: message, type: type))
        }
    }

    /// Detecta el dispositivo y actualiza la UI con su información.
    func detectDevice() async {
        log("Buscando dispositivo...", type: .info)
        do {
            let device = try await deviceCommunicator.detectDevice()
            let properties = try await device.getProperties()
            let _ = properties["UDID"] as? String ?? "UDID_DESCONOCIDO"
            let deviceName = properties["DeviceName"] as? String ?? "Dispositivo"
            let version = properties["ProductVersion"] as? String ?? "iOS"

            DispatchQueue.main.async {
                self.deviceInfo = deviceName
                self.iosVersion = version
                self.detectedDevice = device
                self.isDeveloperModeEnabled = true // Asumimos que si se detecta, el modo desarrollador está activo.
                self.log("Dispositivo detectado: \(deviceName) (iOS \(version))", type: .success)
            }
        } catch {
            log("Error al detectar el dispositivo: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async {
                self.deviceInfo = "No detectado"
                self.iosVersion = "Desconocida"
                self.detectedDevice = nil
            }
        }
    }

    /// Consulta si la imagen DDI ya está montada en el sistema
    func checkDDIMounted() async -> Bool {
        guard let device = detectedDevice else {
            log("No hay dispositivo detectado para verificar DDI.", type: .warning)
            return false
        }
        log("Verificando estado del DDI...", type: .info)
        do {
            let isMounted = try await deviceCommunicator.isDDIMounted(device: device)
            DispatchQueue.main.async {
                self.ddiStatus = isMounted ? .mounted : .notMounted
                self.log(isMounted ? "DDI ya se encuentra montado." : "DDI no está montado.", type: isMounted ? .success : .info)
            }
            return isMounted
        } catch {
            log("Error al verificar DDI: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async { self.ddiStatus = .unknown }
            return false
        }
    }

    /// Intenta el montaje de la imagen personalizada (DDI)
    func mountDDI() async {
        guard let device = detectedDevice else {
            log("No hay dispositivo detectado para montar DDI.", type: .error)
            return
        }
        
        DispatchQueue.main.async {
            self.isMounting = true
            self.mountProgress = 0.0
        }
        
        log("Iniciando proceso de montaje de DDI...", type: .info)
        do {
            let (ddiPath, signaturePath) = try findDDIFor(version: iosVersion)
            
            // Pasamos un closure para recibir las actualizaciones de progreso.
            try await deviceCommunicator.mountDDI(device: device, ddiPath: ddiPath, signaturePath: signaturePath) { progress in
                DispatchQueue.main.async {
                    self.mountProgress = progress
                }
            }
            
            DispatchQueue.main.async {
                self.ddiStatus = .mounted
                self.log("DDI montado exitosamente.", type: .success)
            }
        } catch {
            log("Error al montar DDI: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async { self.ddiStatus = .notMounted }
        }
        
        DispatchQueue.main.async {
            self.isMounting = false
        }
    }

    /// Busca los archivos DDI para una versión específica de iOS en las rutas de Xcode.
    /// - Parameter version: La versión de iOS (ej. "17.5").
    /// - Returns: Una tupla con las rutas al .dmg y al .signature.
    private func findDDIFor(version: String) throws -> (dmgPath: String, signaturePath: String) {
        log("Buscando DDI para iOS \(version)...")
        let fileManager = FileManager.default
        let xcodePath = "/Applications/Xcode.app" // Ruta estándar de Xcode
        let baseDDIPath = "\(xcodePath)/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport"

        // La carpeta de soporte puede ser la versión exacta (17.5) o la mayor/menor (17.0)
        let versionComponents = version.split(separator: ".").map(String.init)
        let majorMinorVersion = versionComponents.prefix(2).joined(separator: ".")

        // Lista de posibles carpetas de versión a verificar
        let possibleVersionFolders = [version, majorMinorVersion].reduce(into: [String]()) { result, versionString in
            if !result.contains(versionString) {
                result.append(versionString)
            }
        }

        for versionFolder in possibleVersionFolders {
            let dmgPath = "\(baseDDIPath)/\(versionFolder)/DeveloperDiskImage.dmg"
            let signaturePath = "\(dmgPath).signature"

            if fileManager.fileExists(atPath: dmgPath) && fileManager.fileExists(atPath: signaturePath) {
                log("DDI encontrado en: \(dmgPath)", type: .success)
                return (dmgPath, signaturePath)
            }
        }

        throw DeviceCommunicationError.mountFailed(details: "No se encontraron archivos DDI para la versión \(version) en la ruta de Xcode.")
    }
}
