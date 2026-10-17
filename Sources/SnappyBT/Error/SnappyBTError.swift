import Foundation

public enum SnappyBTError: Error, Equatable, Sendable {

    // MARK: - Cases

    case invalidUUID(String)
    case unknownPeripheral(UUID)
    case connectionLimitReached(Int)
    case connectionFailed(String)
    case discoveryFailed(String)
    case writeFailed(String)

    // MARK: - Helpers

    static func reason(_ error: Error?) -> String {
        error.map { $0.localizedDescription } ?? "unknown error"
    }
}

// MARK: - LocalizedError

extension SnappyBTError: LocalizedError {

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .invalidUUID(let value): return "Invalid Bluetooth UUID: \(value)"
        case .unknownPeripheral(let id): return "Unknown peripheral: \(id.uuidString)"
        case .connectionLimitReached(let limit): return "Connection limit reached (\(limit))"
        case .connectionFailed(let reason): return "Connection failed: \(reason)"
        case .discoveryFailed(let reason): return "Discovery failed: \(reason)"
        case .writeFailed(let reason): return "Write failed: \(reason)"
        }
    }
}
