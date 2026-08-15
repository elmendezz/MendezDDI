import Foundation

// Changelog
// Version: 1.0.0
// - Estructura de codificación de llaves y certificados de pairing

public struct PairingFile: Codable {
    public let udid: String
    public let deviceCertificate: Data
    public let devicePrivateKey: Data
    public let hostCertificate: Data
    public let hostPrivateKey: Data
    public let rootCertificate: Data

    enum CodingKeys: String, CodingKey {
        case udid = "UDID"
        case deviceCertificate = "DeviceCertificate"
        case devicePrivateKey = "DevicePrivateKey"
        case hostCertificate = "HostCertificate"
        case hostPrivateKey = "HostPrivateKey"
        case rootCertificate = "RootCertificate"
    }
}