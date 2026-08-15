import Foundation

// Changelog
// Version: 1.0.0
// - Almacenamiento seguro persistente del pairing file

public class PairingStore: ObservableObject {
    @Published public var pairingInfo: PairingFile?
    @Published public var isValid: Bool = false

    private let storeKey = "MendezDDI_SavedPairing"

    public init() {
        loadStoredPairing()
    }

    public func importPairing(from url: URL) -> Bool {
        let shouldStopAccess = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccess { url.stopAccessingSecurityScopedResource() } }

        guard let parsed = PairingImporter.parsePairingData(from: url) else { return false }
        
        if PairingValidator.validate(pairing: parsed) {
            self.pairingInfo = parsed
            self.isValid = true
            savePairingToDisk(data: try? PropertyListEncoder().encode(parsed))
            return true
        }
        return false
    }

    private func savePairingToDisk(data: Data?) {
        UserDefaults.standard.set(data, forKey: storeKey)
    }

    private func loadStoredPairing() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let parsed = try? PropertyListDecoder().decode(PairingFile.self, from: data) else { return }
        self.pairingInfo = parsed
        self.isValid = PairingValidator.validate(pairing: parsed)
    }
}