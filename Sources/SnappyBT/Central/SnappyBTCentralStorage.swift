import Foundation

// MARK: - SnappyBTCentralStorage

struct SnappyBTCentralStorage {
    var state: SnappyBTState
    var scanRequested = false
    var scanning = false
    var known = Set<UUID>()
    var connecting = Set<UUID>()
    var connected = Set<UUID>()
    var ready = Set<UUID>()
    var pending: [UUID: [Data]] = [:]
    var pendingAny: [Data] = []
    var lastError: SnappyBTError?
    var onDiscover: (@Sendable (SnappyBTDiscoveredPeripheral) -> Void)?
    var onConnect: (@Sendable (UUID) -> Void)?
    var onDisconnect: (@Sendable (UUID, Error?) -> Void)?
    var onError: (@Sendable (SnappyBTError) -> Void)?
    var onReadyToWrite: (@Sendable (UUID) -> Void)?
    var onStateChanged: (@Sendable (SnappyBTState) -> Void)?
}

struct SnappyBTCentralCallbackSet: Sendable {
    let onDiscover: (@Sendable (SnappyBTDiscoveredPeripheral) -> Void)?
    let onConnect: (@Sendable (UUID) -> Void)?
    let onDisconnect: (@Sendable (UUID, Error?) -> Void)?
    let onError: (@Sendable (SnappyBTError) -> Void)?
    let onReadyToWrite: (@Sendable (UUID) -> Void)?
    let onStateChanged: (@Sendable (SnappyBTState) -> Void)?

    init(_ storage: SnappyBTCentralStorage) {
        onDiscover = storage.onDiscover
        onConnect = storage.onConnect
        onDisconnect = storage.onDisconnect
        onError = storage.onError
        onReadyToWrite = storage.onReadyToWrite
        onStateChanged = storage.onStateChanged
    }
}
