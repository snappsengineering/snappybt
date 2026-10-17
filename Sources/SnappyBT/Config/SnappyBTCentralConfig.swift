import Foundation

public struct SnappyBTCentralConfig: Sendable {

    // MARK: - Properties

    public var serviceUUIDs: [String]
    public var receiveCharacteristicUUID: String
    public var callbackQueue: DispatchQueue
    public var allowDuplicates: Bool
    public var maxConnections: Int
    public var encryption: Encryption?
    public var requireEncryptedLink: Bool

    // MARK: - Lifecycle

    public init(
        serviceUUIDs: [String],
        receiveCharacteristicUUID: String = SnappyBTDefaultRXCharacteristicUUID,
        callbackQueue: DispatchQueue = .main,
        allowDuplicates: Bool = false,
        maxConnections: Int = 1,
        encryption: Encryption? = nil,
        requireEncryptedLink: Bool = false
    ) {
        self.serviceUUIDs = serviceUUIDs
        self.receiveCharacteristicUUID = receiveCharacteristicUUID
        self.callbackQueue = callbackQueue
        self.allowDuplicates = allowDuplicates
        self.maxConnections = maxConnections
        self.encryption = encryption
        self.requireEncryptedLink = requireEncryptedLink
    }

    public init(
        serviceUUIDs: [String],
        receiveCharacteristicUUID: String = SnappyBTDefaultRXCharacteristicUUID,
        callbackQueue: DispatchQueue = .main,
        allowDuplicates: Bool = false,
        maxConnections: Int = 1
    ) {
        self.init(
            serviceUUIDs: serviceUUIDs,
            receiveCharacteristicUUID: receiveCharacteristicUUID,
            callbackQueue: callbackQueue,
            allowDuplicates: allowDuplicates,
            maxConnections: maxConnections,
            encryption: nil,
            requireEncryptedLink: false
        )
    }

    // MARK: - Helpers

    func validate() throws {
        try SnappyBTUUID.validate(serviceUUIDs + [receiveCharacteristicUUID])
    }
}
