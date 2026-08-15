import Foundation
import Network

// Changelog
// Version: 1.0.0
// - Implementación cliente socket async/await sobre Lockdown service

public class LockdownClient {
    private var connection: NWConnection?
    private let host: String
    private let port: UInt16

    public init(host: String = "127.0.0.1", port: UInt16 = 62078) {
        self.host = host
        self.port = port
    }

    public func connect() async throws {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!)
        connection = NWConnection(to: endpoint, using: .tcp)
        
        return try await withCheckedThrowingContinuation { continuation in
            connection?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let err):
                    continuation.resume(throwing: err)
                default:
                    break
                }
            }
            connection?.start(queue: .global())
        }
    }

    public func getValue(key: String) async throws -> [String: Any] {
        let requestDict: [String: Any] = [
            "Request": "GetValue",
            "Key": key,
            "Label": "MendezDDI"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: requestDict, format: .xml, options: 0)
        
        var packet = Data()
        var length = UInt32(plistData.count).bigEndian
        packet.append(Data(bytes: &length, count: 4))
        packet.append(plistData)

        try await send(data: packet)
        let responseData = try await receivePacket()
        
        guard let plist = try PropertyListSerialization.propertyList(from: responseData, options: [], format: nil) as? [String: Any] else {
            throw NSError(domain: "MendezDDI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Respuesta inválida de lockdown"])
        }
        return plist
    }

    private func send(data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            connection?.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }))
        }
    }

    private func receivePacket() async throws -> Data {
        let headerData = try await receive(length: 4)
        let length = headerData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        return try await receive(length: Int(length))
    }

    private func receive(length: Int) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            connection?.receive(exactLength: length) { data, context, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                }
            }
        }
    }
}