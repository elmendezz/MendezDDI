import Foundation

// Changelog
// Version: 1.0.0
// - Coordinador principal de estado y montaje DDI

public class DDIManager: ObservableObject {
    @Published public var mountState: String = "Inactivo"
    @Published public var isProcessing: Bool = false
    @Published public var logMessage: String = ""

    private let downloader = DDIDownloader()
    private let personalizer = DDIPersonalizer()
    private let mounter = DDIMounter()
    private let verifier = DDIVerifier()

    @MainActor
    public func startMountProcess(pairing: PairingFile) async {
        isProcessing = true
        mountState = "Conectando Lockdown..."
        logMessage = "Iniciando cliente Lockdown sobre socket local..."

        do {
            let lockdown = LockdownClient()
            try await lockdown.connect()
            
            logMessage = "Conectado. Verificando versión del dispositivo..."
            mountState = "Verificando DDI..."
            
            let isAlreadyMounted = try await verifier.checkMountedDDI(lockdown: lockdown)
            if isAlreadyMounted {
                mountState = "🟢 DDI ACTIVO"
                logMessage = "El Developer Disk Image ya se encuentra activo en el sistema."
                isProcessing = false
                return
            }

            mountState = "Descargando DDI..."
            logMessage = "Obteniendo Developer Disk Image compatible..."
            let ddiUrl = try await downloader.fetchCompatibleDDI(version: "17.4", build: "21E219")

            mountState = "Personalizando Imagen..."
            logMessage = "Generando firma y manifest personalizado para iOS 17+..."
            let personalizedDDI = try await personalizer.personalizeImage(imageURL: ddiUrl, pairing: pairing)

            mountState = "Montando..."
            logMessage = "Enviando comando de montaje a mobile_image_mounter..."
            let success = try await mounter.mountImage(ddi: personalizedDDI, lockdown: lockdown)

            if success {
                mountState = "🟢 DDI ACTIVO"
                logMessage = "ÉXITO: DDI Montado correctamente de forma nativa."
            } else {
                mountState = "🔴 Fallo de montaje"
                logMessage = "ERROR: mobile_image_mounter rechazó la imagen."
            }
        } catch {
            mountState = "🔴 Error"
            logMessage = "ERROR Excepción: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
}