import Foundation

// Changelog
// Version: 1.0.0
// - Modelo de información técnica del dispositivo

public struct DeviceInfo {
    public var productVersion: String = ""
    public var buildVersion: String = ""
    public var hardwareModel: String = ""
    public var developerModeStatus: Bool = false
}