import Foundation

public struct SnappyBTMessage: Sendable, Equatable {

    // MARK: - Properties

    public let sender: UUID
    public let data: Data
    public var text: String? { String(data: data, encoding: .utf8) }

    // MARK: - Lifecycle

    public init(sender: UUID, data: Data) {
        self.sender = sender
        self.data = data
    }
}
