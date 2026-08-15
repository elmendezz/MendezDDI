// DDIManager.swift
// MendezDDI - Version: 1.0.1
// Changelog:
// v1.0.1 - Inclusión de import UIKit para resolver 'UIDevice' in scope.
// v1.0.0 - Gestor principal para conexiones Lockdown, detección de Developer Mode y verificación de DDI.

import Foundation
import UIKit

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
    @Published var logs: [LogEntry] = []

    func log(_ message: String, type: LogType = .info) {
        DispatchQueue.main.async {
            self.logs.append(LogEntry(message: message, type: type))
        }
    }

    /// Detecta el dispositivo vía Lockdown (Simulación de handshaking preliminar)
    func detectDevice() async -> String {
        log("Buscando dispositivo...", type: .info)
        do {
            let properties = try await deviceCommunicator.detectDevice()
            let udid = properties["UDID"] as? String ?? "UDID_DESCONOCIDO"
            let deviceName = properties["DeviceName"] as? String ?? "Dispositivo"
            let version = properties["ProductVersion"] as? String ?? "iOS"

            DispatchQueue.main.async {
                self.deviceInfo = deviceName
                self.iosVersion = version
                self.isDeveloperModeEnabled = true // Asumimos que si se detecta, el modo desarrollador está activo.
                self.log("Dispositivo detectado: \(deviceName) (iOS \(version))", type: .success)
            }
            return udid
        } catch {
            log("Error al detectar el dispositivo: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async {
                self.deviceInfo = "No detectado"
                self.iosVersion = "Desconocida"
            }
            return ""
        }
    }

    /// Consulta si la imagen DDI ya está montada en el sistema
    func checkDDIMounted(udid: String) async -> Bool {
        guard !udid.isEmpty else { return false }
        log("Verificando estado del DDI...", type: .info)
        do {
            let isMounted = try await deviceCommunicator.isDDIMounted(udid: udid)
            DispatchQueue.main.async {
                self.ddiStatus = isMounted ? .mounted : .notMounted
                self.log(isMounted ? "DDI ya se encuentra montado." : "DDI no está montado.", type: isMounted ? .success : .warning)
            }
            return isMounted
        } catch {
            log("Error al verificar DDI: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async { self.ddiStatus = .unknown }
            return false
        }
    }

    /// Intenta el montaje de la imagen personalizada (DDI)
    func mountDDI(udid: String) async {
        guard !udid.isEmpty else { return }
        log("Iniciando proceso de montaje de DDI...", type: .info)
        do {
            // NOTA: Necesitarás una forma de obtener la ruta al archivo DDI.
            try await deviceCommunicator.mountDDI(udid: udid, ddiPath: "/ruta/a/tu/ddi.dmg")
            DispatchQueue.main.async {
                self.ddiStatus = .mounted
                self.log("DDI montado exitosamente.", type: .success)
            }
        } catch {
            log("Error al montar DDI: \(error.localizedDescription)", type: .error)
            DispatchQueue.main.async { self.ddiStatus = .notMounted }
        }
    }
}
