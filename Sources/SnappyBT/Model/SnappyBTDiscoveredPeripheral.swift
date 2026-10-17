import Foundation

public struct SnappyBTDiscoveredPeripheral: Sendable, Equatable {

    // MARK: - Properties

    public let identifier: UUID
    public let name: String?
    public let rssi: Int
    public let serviceUUIDs: [String]
    public let manufacturerData: Data?

    // MARK: - Lifecycle

    public init(
        identifier: UUID,
        name: String?,
        rssi: Int,
        serviceUUIDs: [String] = [],
        manufacturerData: Data? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.rssi = rssi
        self.serviceUUIDs = serviceUUIDs
        self.manufacturerData = manufacturerData
    }
}
