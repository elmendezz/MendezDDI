import Foundation

// Changelog
// Version: 1.0.0
// - Modelo de DDI, firma e imagen personalizada

public struct DDIImage {
    public let imagePath: URL
    public let signaturePath: URL
    public let manifestPath: URL?
    public let isPersonalized: Bool
}