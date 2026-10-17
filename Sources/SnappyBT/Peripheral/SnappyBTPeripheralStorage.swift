import Foundation

// MARK: - SnappyBTPeripheralStorage

struct SnappyBTPeripheralStorage {
    var state: SnappyBTState
    var advertisingRequested = false
    var lastError: SnappyBTError?
    var onReceive: (@Sendable (Data) -> Void)?
    var onReceiveText: (@Sendable (String) -> Void)?
    var onMessage: (@Sendable (SnappyBTMessage) -> Void)?
    var onStateChanged: (@Sendable (SnappyBTState) -> Void)?
    var onError: (@Sendable (SnappyBTError) -> Void)?
}
