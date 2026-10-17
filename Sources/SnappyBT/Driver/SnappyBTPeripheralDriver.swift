import Foundation

// MARK: - SnappyBTPeripheralDriverEvent

public enum SnappyBTPeripheralDriverEvent: Sendable {
    case stateChanged(SnappyBTState)
    case received(Data, from: UUID, respond: @Sendable (Bool) -> Void)
}

// MARK: - SnappyBTPeripheralDriver

public protocol SnappyBTPeripheralDriver: AnyObject, Sendable {
    var state: SnappyBTState { get }
    var isAdvertising: Bool { get }
    var onEvent: (@Sendable (SnappyBTPeripheralDriverEvent) -> Void)? { get set }
    func startAdvertising(serviceUUID: String, receiveCharacteristicUUID: String, localName: String?)
    func stopAdvertising()
}

// MARK: - SnappyBTLinkSecuring

public protocol SnappyBTLinkSecuring: AnyObject, Sendable {
    var requireEncryptedLink: Bool { get set }
}
