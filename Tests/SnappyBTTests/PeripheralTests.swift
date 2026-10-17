import XCTest
@testable import SnappyBT

// MARK: - PeripheralTests

final class PeripheralTests: XCTestCase {
    private var driver: MockPeripheralDriver!
    private let sender = UUID()

    private func make(name: String = "") throws -> SnappyBTPeripheral {
        driver = MockPeripheralDriver()
        let config = SnappyBTPeripheralConfig(serviceUUID: testService, localName: name, callbackQueue: testQueue)
        return try SnappyBTPeripheral(config: config, driver: driver)
    }

    func testInitRejectsInvalidUUID() {
        let bad = SnappyBTPeripheralConfig(serviceUUID: testService, receiveCharacteristicUUID: "zz", callbackQueue: testQueue)
        XCTAssertThrowsError(try SnappyBTPeripheral(config: bad, driver: MockPeripheralDriver())) {
            XCTAssertEqual($0 as? SnappyBTError, .invalidUUID("zz"))
        }
    }

    func testAdvertisingDefersUntilPoweredOn() throws {
        let p = try make(name: "Name")
        p.startAdvertising()
        XCTAssertTrue(driver.starts.isEmpty)
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertEqual(driver.starts.count, 1)
        XCTAssertEqual(driver.starts[0].service, testService)
        XCTAssertFalse(driver.starts[0].encrypted)
        XCTAssertEqual(driver.starts[0].rx, SnappyBTDefaultRXCharacteristicUUID)
        XCTAssertEqual(driver.starts[0].name, "Name")
        XCTAssertTrue(p.isAdvertising)
        XCTAssertEqual(p.state, .poweredOn)
    }

    func testEmptyLocalNameIsOmittedAndImmediateStart() throws {
        let p = try make()
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertTrue(driver.starts.isEmpty)
        p.startAdvertising()
        XCTAssertEqual(driver.starts.count, 1)
        XCTAssertNil(driver.starts[0].name)
    }

    func testStopAdvertisingCancelsRequest() throws {
        let p = try make()
        p.startAdvertising()
        p.stopAdvertising()
        XCTAssertEqual(driver.stopCount, 1)
        driver.emit(.stateChanged(.poweredOn))
        XCTAssertTrue(driver.starts.isEmpty)
    }

    func testStateCallback() throws {
        let p = try make()
        let seen = Recorder<SnappyBTState>()
        p.onStateChanged = { seen.add($0) }
        driver.emit(.stateChanged(.poweredOff))
        flush()
        XCTAssertEqual(seen.all, [.poweredOff])
    }

    func testReceiveTextAndData() throws {
        let p = try make()
        let data = Recorder<Data>(), text = Recorder<String>(), responses = Recorder<Bool>()
        p.onReceive = { data.add($0) }
        p.onReceiveText = { text.add($0) }
        driver.emit(.received(Data("hello".utf8), from: sender, respond: { responses.add($0) }))
        flush()
        XCTAssertEqual(data.all, [Data("hello".utf8)])
        XCTAssertEqual(text.all, ["hello"])
        XCTAssertEqual(responses.all, [true])
    }

    func testNonUTF8OnlyReachesDataCallback() throws {
        let p = try make()
        let data = Recorder<Data>(), text = Recorder<String>()
        p.onReceive = { data.add($0) }
        p.onReceiveText = { text.add($0) }
        driver.emit(.received(Data([0xFF, 0xFE]), from: sender, respond: { _ in }))
        flush()
        XCTAssertEqual(data.all.count, 1)
        XCTAssertTrue(text.all.isEmpty)
    }

    func testEmptyWriteIsRejected() throws {
        let p = try make()
        let data = Recorder<Data>(), responses = Recorder<Bool>()
        p.onReceive = { data.add($0) }
        driver.emit(.received(Data(), from: sender, respond: { responses.add($0) }))
        flush()
        XCTAssertEqual(responses.all, [false])
        XCTAssertTrue(data.all.isEmpty)
    }

    func testReceiveWithoutCallbacksIsSafe() throws {
        _ = try make()
        driver.emit(.received(Data("x".utf8), from: sender, respond: { _ in }))
        driver.emit(.stateChanged(.poweredOn))
        flush()
    }

    func testCallbackPropertiesRoundTrip() throws {
        let p = try make()
        XCTAssertNil(p.onReceive)
        p.onReceive = { _ in }
        p.onReceiveText = { _ in }
        p.onStateChanged = { _ in }
        XCTAssertNotNil(p.onReceive)
        XCTAssertNotNil(p.onReceiveText)
        XCTAssertNotNil(p.onStateChanged)
    }

    func testManyCentralsToOnePeripheralCarrySender() throws {
        let p = try make()
        let messages = Recorder<SnappyBTMessage>()
        p.onMessage = { messages.add($0) }
        let a = UUID(), b = UUID()
        driver.emit(.received(Data("from a".utf8), from: a, respond: { _ in }))
        driver.emit(.received(Data([0xFF]), from: b, respond: { _ in }))
        flush()
        XCTAssertEqual(messages.all.map(\.sender), [a, b])
        XCTAssertEqual(messages.all.map(\.text), ["from a", nil])
        XCTAssertNotNil(p.onMessage)
    }

    func testRequireEncryptedLinkIsPassedToDriver() throws {
        driver = MockPeripheralDriver()
        let config = SnappyBTPeripheralConfig(serviceUUID: testService, callbackQueue: testQueue, requireEncryptedLink: true)
        let p = try SnappyBTPeripheral(config: config, driver: driver)
        driver.emit(.stateChanged(.poweredOn))
        p.startAdvertising()
        XCTAssertEqual(driver.starts[0].encrypted, true)
    }

    func testEncryptedRoundTrip() throws {
        let key = Encryption.generateKey()
        driver = MockPeripheralDriver()
        let config = SnappyBTPeripheralConfig(serviceUUID: testService, callbackQueue: testQueue, encryption: Encryption(key: key))
        let p = try SnappyBTPeripheral(config: config, driver: driver)
        let received = Recorder<String>()
        let errors = Recorder<SnappyBTError>()
        p.onReceiveText = { received.add($0) }
        p.onError = { errors.add($0) }
        let sealed = try Encryption(key: key).encrypt(Data("secret".utf8))
        driver.emit(.received(sealed, from: sender, respond: { _ in }))
        flush()
        XCTAssertEqual(received.all, ["secret"])
        XCTAssertTrue(errors.all.isEmpty)
    }

    func testWrongKeyRejectsAndReports() throws {
        driver = MockPeripheralDriver()
        let config = SnappyBTPeripheralConfig(
            serviceUUID: testService,
            callbackQueue: testQueue,
            encryption: Encryption(key: Encryption.generateKey())
        )
        let p = try SnappyBTPeripheral(config: config, driver: driver)
        let received = Recorder<Data>()
        let responses = Recorder<Bool>()
        p.onReceive = { received.add($0) }
        let sealed = try Encryption(key: Encryption.generateKey()).encrypt(Data("x".utf8))
        driver.emit(.received(sealed, from: sender, respond: { responses.add($0) }))
        flush()
        XCTAssertEqual(responses.all, [false])
        XCTAssertTrue(received.all.isEmpty)
        XCTAssertNotNil(p.lastError)
        if case .writeFailed(let reason) = p.lastError {
            XCTAssertTrue(reason.contains("decryption"))
        } else { XCTFail("expected writeFailed") }
        p.clearError()
        XCTAssertNil(p.lastError)
        XCTAssertNil(p.onError)
    }

    func testDriverWithoutLinkSecuringStillAdvertises() throws {
        final class Bare: SnappyBTPeripheralDriver, @unchecked Sendable {
            var state: SnappyBTState = .poweredOn
            var isAdvertising = false
            var onEvent: (@Sendable (SnappyBTPeripheralDriverEvent) -> Void)?
            var started = false
            func startAdvertising(serviceUUID: String, receiveCharacteristicUUID: String, localName: String?) {
                started = true
            }
            func stopAdvertising() {}
        }
        let bare = Bare()
        let p = try SnappyBTPeripheral(
            config: SnappyBTPeripheralConfig(serviceUUID: testService, callbackQueue: testQueue, requireEncryptedLink: true),
            driver: bare
        )
        p.startAdvertising()
        XCTAssertTrue(bare.started)
    }

    func testErrorPropertyRoundTrip() throws {
        let p = try make()
        XCTAssertNil(p.onError)
        p.onError = { _ in }
        XCTAssertNotNil(p.onError)
    }

}
