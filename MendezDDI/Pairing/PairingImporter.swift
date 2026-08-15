import Foundation

// Changelog
// Version: 1.0.0
// - Parser de archivos .plist y .mobiledevicepairing

public class PairingImporter {
    public static func parsePairingData(from url: URL) -> PairingFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let plist = try? PropertyListDecoder().decode(PairingFile.self, from: data) {
            return plist
        }
        return nil
    }
}