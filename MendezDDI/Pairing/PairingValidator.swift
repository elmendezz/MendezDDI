import Foundation

// Changelog
// Version: 1.0.0
// - Validador de integridades de certificados de pairing

public class PairingValidator {
    public static func validate(pairing: PairingFile) -> Bool {
        return !pairing.udid.isEmpty && !pairing.deviceCertificate.isEmpty
    }
}