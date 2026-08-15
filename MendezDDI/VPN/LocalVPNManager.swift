import Foundation

// Changelog
// Version: 1.0.0
// - Gestor de estado de la interfaz VPN local

public enum VPNStatusEnum: String {
    case disconnected = "Desconectado"
    case connecting = "Conectando..."
    case connected = "Conectado (LocalDevVPN)"
}

public class LocalVPNManager: ObservableObject {
    @Published public var status: VPNStatusEnum = .connected
}