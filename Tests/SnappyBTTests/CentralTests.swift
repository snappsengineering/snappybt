import CryptoKit
import XCTest
@testable import SnappyBT

// MARK: - CentralTests

final class CentralTests: XCTestCase {
    private var driver: MockCentralDriver!
    private var central: SnappyBTCentral!
    private let peerID = UUID()

    override func setUpWithError() throws {
        driver = MockCentralDriver()
        let config = SnappyBTCentralConfig(serviceUUIDs: [testService], callbackQueue: testQueue, allowDuplicates: true)
        central = try SnappyBTCentral(config: config, driver: driver)
    }

    private func discoverPeer() {
        driver.emit(.discovered(SnappyBTDiscoveredPeripheral(identifier: peerID, name: "P", rssi: -40)))
    }

    private func connectAndReady() {
        discoverPeer()
        central.connect(to: peerID)
        driver.emit(.connected(peerID))
        driver.emit(.readyToWrite(peerID))
        flush()
    }

    func testInitRejectsInvalidUUID() {
        let bad = SnappyBTCentralConfig(serviceUUIDs: ["not-a-uuid"], callbackQueue: testQueue)
        XCTAssertThrowsError(try SnappyBTCentral(config: bad, driver: MockCentralDriver())) {
            XCTAssertEqual($0 as? SnappyBTError, .invalidUUID("not-a-uuid"))
        }
    }

    func testInitTakesDriverState() throws {
        let d = MockCentralDriver()
        d.state = .poweredOn
        let c = try SnappyBTCentral(config: SnappyBTCentralConfig(serviceUUIDs: [testService]), driver: d)
        XCTAssertEqual(c.state, .poweredOn)
    }

    func testScanDefersUntilPoweredOn() {
        central.startScanning()
        XCTAssertTrue(driver.scans.isEmpty)
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertEqual(driver.scans.count, 1)
        XCTAssertEqual(driver.scans[0].services, [testService])
        XCTAssertTrue(driver.scans[0].duplicates)
        XCTAssertEqual(central.state, .poweredOn)
    }

    func testScanStartsImmediatelyWhenPoweredOnAndOnlyOnce() {
        driver.emit(.stateChanged(.poweredOn))
        central.startScanning()
        central.startScanning()
        XCTAssertEqual(driver.scans.count, 1)
    }

    func testPoweredOnWithoutRequestDoesNotScan() {
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertTrue(driver.scans.isEmpty)
    }

    func testRepeatedPoweredOnDoesNotRestartScan() {
        central.startScanning()
        driver.emit(.stateChanged(.poweredOn))
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertEqual(driver.scans.count, 1)
    }

    func testScanResumesAfterRadioCycle() {
        central.startScanning()
        driver.emit(.stateChanged(.poweredOn))
        driver.emit(.stateChanged(.poweredOff))
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertEqual(driver.scans.count, 2)
    }

    func testStopScanningCancelsRequest() {
        central.startScanning()
        central.stopScanning()
        XCTAssertEqual(driver.stopScanCount, 1)
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertTrue(driver.scans.isEmpty)
    }

    func testIsScanningTracksActiveScan() {
        XCTAssertFalse(central.isScanning)
        central.startScanning()
        XCTAssertFalse(central.isScanning)
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertTrue(central.isScanning)
        central.stopScanning()
        XCTAssertFalse(central.isScanning)
    }

    func testStateChangedCallback() {
        let seen = Recorder<SnappyBTState>()
        central.onStateChanged = { seen.add($0) }
        driver.emit(.stateChanged(.unauthorized))
        flush()
        XCTAssertEqual(seen.all, [.unauthorized])
    }

    func testDiscoverConnectDisconnectCallbacks() {
        let discovered = Recorder<UUID>(), connected = Recorder<UUID>(), disconnected = Recorder<UUID>()
        let disconnectError = Recorder<Bool>()
        central.onDiscover = { discovered.add($0.identifier) }
        central.onConnect = { connected.add($0) }
        central.onDisconnect = { id, error in disconnected.add(id); disconnectError.add(error != nil) }
        discoverPeer()
        central.connect(to: peerID)
        driver.emit(.connected(peerID))
        driver.emit(.disconnected(peerID, TestError()))
        flush()
        XCTAssertEqual(driver.connects, [peerID])
        XCTAssertEqual(discovered.all, [peerID])
        XCTAssertEqual(connected.all, [peerID])
        XCTAssertEqual(disconnected.all, [peerID])
        XCTAssertEqual(disconnectError.all, [true])
    }

    func testEventsWithoutCallbacksAreSafe() {
        discoverPeer()
        driver.emit(.connected(peerID))
        driver.emit(.readyToWrite(peerID))
        driver.emit(.disconnected(peerID, nil))
        driver.emit(.connectionFailed(peerID, nil))
        driver.emit(.stateChanged(.poweredOn))
        flush()
        XCTAssertNotNil(central.lastError)
    }

    func testConnectUnknownReportsError() {
        let errors = Recorder<SnappyBTError>()
        central.onError = { errors.add($0) }
        central.connect(to: peerID)
        flush()
        XCTAssertEqual(errors.all, [.unknownPeripheral(peerID)])
        XCTAssertEqual(central.lastError, .unknownPeripheral(peerID))
        XCTAssertTrue(driver.connects.isEmpty)
        central.clearError()
        XCTAssertNil(central.lastError)
    }

    func testDisconnectedPeripheralBecomesUnknown() {
        discoverPeer()
        driver.emit(.disconnected(peerID, nil))
        central.connect(to: peerID)
        XCTAssertEqual(central.lastError, .unknownPeripheral(peerID))
    }

    func testWritesQueueUntilReadyThenFlushInOrder() {
        central.write(data: Data([1]))
        central.write(text: "two")
        XCTAssertTrue(driver.writes.isEmpty)
        let ready = Recorder<UUID>()
        central.onReadyToWrite = { ready.add($0) }
        connectAndReady()
        XCTAssertEqual(ready.all, [peerID])
        XCTAssertEqual(driver.writes.map(\.data), [Data([1]), Data("two".utf8)])
        XCTAssertEqual(driver.writes.map(\.id), [peerID, peerID])
        central.write(text: "three")
        XCTAssertEqual(driver.writes.last?.data, Data("three".utf8))
        XCTAssertEqual(driver.writes.count, 3)
    }

    func testDisconnectClearsReadyAndQueue() {
        connectAndReady()
        central.disconnect()
        XCTAssertEqual(driver.disconnects, [peerID])
        central.write(text: "later")
        XCTAssertTrue(driver.writes.isEmpty)
        driver.emit(.readyToWrite(peerID))
        XCTAssertEqual(driver.writes.count, 1)
    }

    func testDisconnectWhileNotConnectedIsNoop() {
        central.write(text: "queued")
        central.disconnect()
        XCTAssertTrue(driver.disconnects.isEmpty)
    }

    func testDisconnectEventDropsReadyAndPending() {
        connectAndReady()
        driver.emit(.disconnected(peerID, nil))
        central.write(text: "x")
        driver.emit(.disconnected(peerID, nil))
        driver.emit(.readyToWrite(peerID))
        XCTAssertEqual(driver.writes.count, 1)
    }

    func testDisconnectEventForOtherPeripheralKeepsState() {
        connectAndReady()
        driver.emit(.disconnected(UUID(), nil))
        central.write(text: "still ready")
        XCTAssertEqual(driver.writes.count, 1)
        central.disconnect()
        XCTAssertEqual(driver.disconnects, [peerID])
    }

    func testErrorsFromDriver() {
        let errors = Recorder<SnappyBTError>()
        central.onError = { errors.add($0) }
        driver.emit(.connectionFailed(peerID, TestError()))
        driver.emit(.writeCompleted(peerID, TestError()))
        driver.emit(.writeCompleted(peerID, nil))
        driver.emit(.discoveryFailed(peerID, nil))
        flush()
        XCTAssertEqual(errors.all, [
            .connectionFailed("synthetic failure"),
            .writeFailed("synthetic failure"),
            .discoveryFailed("unknown error"),
        ])
        XCTAssertEqual(central.lastError, .discoveryFailed("unknown error"))
    }

    func testCallbackPropertiesRoundTrip() {
        XCTAssertNil(central.onDiscover)
        central.onDiscover = { _ in }
        central.onConnect = { _ in }
        central.onDisconnect = { _, _ in }
        central.onError = { _ in }
        central.onReadyToWrite = { _ in }
        central.onStateChanged = { _ in }
        XCTAssertNotNil(central.onDiscover)
        XCTAssertNotNil(central.onConnect)
        XCTAssertNotNil(central.onDisconnect)
        XCTAssertNotNil(central.onError)
        XCTAssertNotNil(central.onReadyToWrite)
        XCTAssertNotNil(central.onStateChanged)
    }

    // MARK: One-to-many

    private func makeMany(limit: Int) throws -> (SnappyBTCentral, MockCentralDriver) {
        let d = MockCentralDriver()
        let config = SnappyBTCentralConfig(serviceUUIDs: [testService], callbackQueue: testQueue, maxConnections: limit)
        return (try SnappyBTCentral(config: config, driver: d), d)
    }

    private func bringUp(_ c: SnappyBTCentral, _ d: MockCentralDriver, _ ids: [UUID]) {
        for id in ids {
            d.emit(.discovered(SnappyBTDiscoveredPeripheral(identifier: id, name: nil, rssi: 0)))
            c.connect(to: id)
            d.emit(.connected(id))
            d.emit(.readyToWrite(id))
        }
        flush()
    }

    func testOneToManyConnectsUpToLimit() throws {
        let (c, d) = try makeMany(limit: 2)
        let ids = [UUID(), UUID(), UUID()]
        for id in ids { d.emit(.discovered(SnappyBTDiscoveredPeripheral(identifier: id, name: nil, rssi: 0))) }
        c.connect(to: ids[0])
        c.connect(to: ids[0])
        c.connect(to: ids[1])
        c.connect(to: ids[2])
        XCTAssertEqual(d.connects, [ids[0], ids[1]])
        XCTAssertEqual(c.lastError, .connectionLimitReached(2))
        d.emit(.connected(ids[0]))
        c.connect(to: ids[0])
        XCTAssertEqual(d.connects.count, 2)
    }

    func testDefaultAndInvalidLimitMeanOneToOne() throws {
        for limit in [1, 0, -3] {
            let (c, d) = try makeMany(limit: limit)
            let a = UUID(), b = UUID()
            for id in [a, b] { d.emit(.discovered(SnappyBTDiscoveredPeripheral(identifier: id, name: nil, rssi: 0))) }
            c.connect(to: a)
            c.connect(to: b)
            XCTAssertEqual(d.connects, [a])
            XCTAssertEqual(c.lastError, .connectionLimitReached(1))
        }
    }

    func testFailedConnectionFreesASlot() throws {
        let (c, d) = try makeMany(limit: 1)
        let a = UUID(), b = UUID()
        for id in [a, b] { d.emit(.discovered(SnappyBTDiscoveredPeripheral(identifier: id, name: nil, rssi: 0))) }
        c.connect(to: a)
        d.emit(.connectionFailed(a, TestError()))
        c.connect(to: b)
        XCTAssertEqual(d.connects, [a, b])
    }

    func testBroadcastReachesEveryReadyPeripheral() throws {
        let (c, d) = try makeMany(limit: 3)
        let ids = [UUID(), UUID()]
        bringUp(c, d, ids)
        XCTAssertEqual(Set(c.connectedPeripherals), Set(ids))
        XCTAssertEqual(Set(c.readyPeripherals), Set(ids))
        c.write(text: "all")
        XCTAssertEqual(Set(d.writes.map(\.id)), Set(ids))
        XCTAssertEqual(d.writes.count, 2)
    }

    func testTargetedWritesQueueThenSendOnlyToTarget() throws {
        let (c, d) = try makeMany(limit: 2)
        let a = UUID(), b = UUID()
        c.write(text: "for a", to: a)
        c.write(data: Data([9]), to: a)
        bringUp(c, d, [b])
        XCTAssertTrue(d.writes.isEmpty)
        bringUp(c, d, [a])
        XCTAssertEqual(d.writes.map(\.data), [Data("for a".utf8), Data([9])])
        XCTAssertEqual(Set(d.writes.map(\.id)), [a])
        c.write(text: "direct", to: b)
        XCTAssertEqual(d.writes.last?.id, b)
    }

    func testUntargetedQueueGoesToFirstPeripheralReady() throws {
        let (c, d) = try makeMany(limit: 2)
        let a = UUID(), b = UUID()
        c.write(text: "hello")
        bringUp(c, d, [a, b])
        XCTAssertEqual(d.writes.count, 1)
        XCTAssertEqual(d.writes[0].id, a)
    }

    func testDisconnectFromOnePeripheral() throws {
        let (c, d) = try makeMany(limit: 2)
        let a = UUID(), b = UUID()
        bringUp(c, d, [a, b])
        c.write(text: "queued", to: UUID())
        c.disconnect(from: a)
        XCTAssertEqual(d.disconnects, [a])
        XCTAssertEqual(c.readyPeripherals, [b])
        c.disconnect(from: a)
        XCTAssertEqual(d.disconnects, [a])
    }

    func testDisconnectAllHitsEveryPeripheral() throws {
        let (c, d) = try makeMany(limit: 3)
        let ids = [UUID(), UUID()]
        bringUp(c, d, ids)
        c.disconnect()
        XCTAssertEqual(Set(d.disconnects), Set(ids))
        XCTAssertTrue(c.connectedPeripherals.isEmpty)
        XCTAssertTrue(c.readyPeripherals.isEmpty)
    }

    func testDisconnectFromConnectingPeripheral() throws {
        let (c, d) = try makeMany(limit: 2)
        let a = UUID()
        d.emit(.discovered(SnappyBTDiscoveredPeripheral(identifier: a, name: nil, rssi: 0)))
        c.connect(to: a)
        c.disconnect(from: a)
        XCTAssertEqual(d.disconnects, [a])
        c.disconnect(from: a)
        XCTAssertEqual(d.disconnects.count, 1)
    }

    func testDisconnectOfOneLeavesOthersWriting() throws {
        let (c, d) = try makeMany(limit: 2)
        let a = UUID(), b = UUID()
        bringUp(c, d, [a, b])
        d.emit(.disconnected(a, nil))
        flush()
        c.write(text: "x")
        XCTAssertEqual(d.writes.map(\.id), [b])
    }

    func testMaxConnectionsDefaultsToOne() {
        XCTAssertEqual(SnappyBTCentralConfig(serviceUUIDs: [testService]).maxConnections, 1)
    }

    func testWriteSealsPayload() throws {
        let key = Encryption.generateKey()
        let d = MockCentralDriver()
        let config = SnappyBTCentralConfig(serviceUUIDs: [testService], callbackQueue: testQueue, encryption: Encryption(key: key))
        let c = try SnappyBTCentral(config: config, driver: d)
        let id = UUID()
        d.emit(.discovered(SnappyBTDiscoveredPeripheral(identifier: id, name: nil, rssi: 0)))
        c.connect(to: id)
        d.emit(.connected(id))
        d.emit(.readyToWrite(id))
        c.write(text: "secret")
        XCTAssertEqual(d.writes.count, 1)
        XCTAssertNotEqual(d.writes[0].data, Data("secret".utf8))
        XCTAssertEqual(try Encryption(key: key).decrypt(d.writes[0].data), Data("secret".utf8))
    }

    func testEncryptFailureReportsError() throws {
        let d = MockCentralDriver()
        let config = SnappyBTCentralConfig(
            serviceUUIDs: [testService],
            callbackQueue: testQueue,
            encryption: Encryption(key: SymmetricKey(data: Data([1])))
        )
        let c = try SnappyBTCentral(config: config, driver: d)
        c.write(text: "x")
        flush()
        XCTAssertTrue(d.writes.isEmpty)
        if case .writeFailed(let reason) = c.lastError {
            XCTAssertTrue(reason.contains("encryption"))
        } else { XCTFail("expected writeFailed") }

        c.clearError()
        c.write(text: "y", to: peerID)
        flush()
        XCTAssertTrue(d.writes.isEmpty)
        if case .writeFailed(let reason) = c.lastError {
            XCTAssertTrue(reason.contains("encryption"))
        } else { XCTFail("expected writeFailed for targeted write") }
    }

    func testRequireEncryptedLinkDefaultsFalse() {
        XCTAssertFalse(SnappyBTCentralConfig(serviceUUIDs: [testService]).requireEncryptedLink)
        XCTAssertNil(SnappyBTCentralConfig(serviceUUIDs: [testService]).encryption)
    }
}
