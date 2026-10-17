import Foundation

// MARK: - SnappyBTCentralDriverEvent

public enum SnappyBTCentralDriverEvent: Sendable {
    case stateChanged(SnappyBTState)
    case discovered(SnappyBTDiscoveredPeripheral)
    case connected(UUID)
    case connectionFailed(UUID, Error?)
    case disconnected(UUID, Error?)
    case readyToWrite(UUID)
    case writeCompleted(UUID, Error?)
    case discoveryFailed(UUID, Error?)
}

// MARK: - SnappyBTCentralDriver

public protocol SnappyBTCentralDriver: AnyObject, Sendable {
    var state: SnappyBTState { get }
    var onEvent: (@Sendable (SnappyBTCentralDriverEvent) -> Void)? { get set }
    func startScan(serviceUUIDs: [String], allowDuplicates: Bool)
    func stopScan()
    func connect(_ identifier: UUID)
    func disconnect(_ identifier: UUID)
    func write(_ data: Data, to identifier: UUID)
}
