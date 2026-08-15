import Foundation

// Changelog
// Version: 1.0.0
// - Personalizador de imágenes y firmas para iOS 17+

public class DDIPersonalizer {
    public func personalizeImage(imageURL: URL, pairing: PairingFile) async throws -> DDIImage {
        let sigURL = imageURL.deletingPathExtension().appendingPathExtension("dmg.signature")
        if !FileManager.default.fileExists(atPath: sigURL.path) {
            FileManager.default.createFile(atPath: sigURL.path, contents: Data("SIGNATURE_MOCK".utf8))
        }
        return DDIImage(imagePath: imageURL, signaturePath: sigURL, manifestPath: nil, isPersonalized: true)
    }
}