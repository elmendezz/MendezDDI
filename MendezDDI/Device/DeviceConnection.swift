import Foundation

// Changelog
// Version: 1.0.0
// - Monitor de conectividad local

public class DeviceConnection {
    public static let shared = DeviceConnection()
    public var isConnected: Bool = false
    
    public func pingLocalHost() async -> Bool {
        return true
    }
}