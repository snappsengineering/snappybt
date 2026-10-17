import Foundation
@testable import SnappyBT

// MARK: - Test helpers

final class Recorder<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [T] = []
    func add(_ item: T) { lock.lock(); items.append(item); lock.unlock() }
    var all: [T] { lock.lock(); defer { lock.unlock() }; return items }
}

struct TestError: Error, LocalizedError, Equatable {
    var errorDescription: String? { "synthetic failure" }
}

final class MockCentralDriver: SnappyBTCentralDriver, @unchecked Sendable {
    var state: SnappyBTState = .poweredOff
    var onEvent: (@Sendable (SnappyBTCentralDriverEvent) -> Void)?
    private(set) var scans: [(services: [String], duplicates: Bool)] = []
    private(set) var stopScanCount = 0
    private(set) var connects: [UUID] = []
    private(set) var disconnects: [UUID] = []
    private(set) var writes: [(data: Data, id: UUID)] = []

    func startScan(serviceUUIDs: [String], allowDuplicates: Bool) { scans.append((serviceUUIDs, allowDuplicates)) }
    func stopScan() { stopScanCount += 1 }
    func connect(_ identifier: UUID) { connects.append(identifier) }
    func disconnect(_ identifier: UUID) { disconnects.append(identifier) }
    func write(_ data: Data, to identifier: UUID) { writes.append((data, identifier)) }

    func emit(_ event: SnappyBTCentralDriverEvent) { onEvent?(event) }
}

final class MockPeripheralDriver: SnappyBTPeripheralDriver, SnappyBTLinkSecuring, @unchecked Sendable {
    var state: SnappyBTState = .poweredOff
    var isAdvertising = false
    var onEvent: (@Sendable (SnappyBTPeripheralDriverEvent) -> Void)?
    private(set) var starts: [(service: String, rx: String, name: String?, encrypted: Bool)] = []
    private(set) var stopCount = 0
    var requireEncryptedLink = false

    func startAdvertising(serviceUUID: String, receiveCharacteristicUUID: String, localName: String?) {
        starts.append((serviceUUID, receiveCharacteristicUUID, localName, requireEncryptedLink))
        isAdvertising = true
    }
    func stopAdvertising() { stopCount += 1; isAdvertising = false }

    func emit(_ event: SnappyBTPeripheralDriverEvent) { onEvent?(event) }
}

let testService = "4DF91029-1234-463E-9F48-BAB077BF3EF5"
let testQueue = DispatchQueue(label: "snappybt.tests")

func flush() { testQueue.sync {} }
