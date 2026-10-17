import Foundation

// MARK: - SnappyBTState

public enum SnappyBTState: Sendable, Equatable {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn
}
