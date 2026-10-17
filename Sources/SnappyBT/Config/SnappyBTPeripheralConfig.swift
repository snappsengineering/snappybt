import Foundation

public let SnappyBTDefaultRXCharacteristicUUID = "3B66D024-2336-4F22-A980-8095F4898C42"

public struct SnappyBTPeripheralConfig: Sendable {

    // MARK: - Properties

    public var serviceUUID: String
    public var receiveCharacteristicUUID: String
    public var localName: String
    public var callbackQueue: DispatchQueue
    public var encryption: Encryption?
    public var requireEncryptedLink: Bool

    // MARK: - Lifecycle

    public init(
        serviceUUID: String,
        receiveCharacteristicUUID: String = SnappyBTDefaultRXCharacteristicUUID,
        localName: String = "",
        callbackQueue: DispatchQueue = .main,
        encryption: Encryption? = nil,
        requireEncryptedLink: Bool = false
    ) {
        self.serviceUUID = serviceUUID
        self.receiveCharacteristicUUID = receiveCharacteristicUUID
        self.localName = localName
        self.callbackQueue = callbackQueue
        self.encryption = encryption
        self.requireEncryptedLink = requireEncryptedLink
    }

    public init(
        serviceUUID: String,
        receiveCharacteristicUUID: String = SnappyBTDefaultRXCharacteristicUUID,
        localName: String = "",
        callbackQueue: DispatchQueue = .main
    ) {
        self.init(
            serviceUUID: serviceUUID,
            receiveCharacteristicUUID: receiveCharacteristicUUID,
            localName: localName,
            callbackQueue: callbackQueue,
            encryption: nil,
            requireEncryptedLink: false
        )
    }

    // MARK: - Helpers

    func validate() throws {
        try SnappyBTUUID.validate([serviceUUID, receiveCharacteristicUUID])
    }
}
