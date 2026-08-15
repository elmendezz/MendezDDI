import Foundation

// Changelog
// Version: 1.0.0
// - Almacén centralizado de diagnósticos

public class Diagnostics: ObservableObject {
    @Published public var logHistory: [String] = []

    public func log(_ text: String) {
        logHistory.append(text)
    }
}