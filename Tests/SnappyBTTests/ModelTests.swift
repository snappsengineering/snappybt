import XCTest
@testable import SnappyBT

// MARK: - ModelTests

final class ModelTests: XCTestCase {
    func testDefaultRXUUID() {
        XCTAssertEqual(SnappyBTDefaultRXCharacteristicUUID, "3B66D024-2336-4F22-A980-8095F4898C42")
    }

    func testConfigDefaults() {
        let p = SnappyBTPeripheralConfig(serviceUUID: testService)
        XCTAssertEqual(p.receiveCharacteristicUUID, SnappyBTDefaultRXCharacteristicUUID)
        XCTAssertEqual(p.localName, "")
        let c = SnappyBTCentralConfig(serviceUUIDs: [testService])
        XCTAssertEqual(c.receiveCharacteristicUUID, SnappyBTDefaultRXCharacteristicUUID)
        XCTAssertFalse(c.allowDuplicates)
    }

    func testUUIDValidation() {
        XCTAssertTrue(SnappyBTUUID.isValid(testService))
        XCTAssertTrue(SnappyBTUUID.isValid("180F"))
        XCTAssertTrue(SnappyBTUUID.isValid("0000180F"))
        XCTAssertFalse(SnappyBTUUID.isValid("180"))
        XCTAssertFalse(SnappyBTUUID.isValid("ZZZZ"))
        XCTAssertFalse(SnappyBTUUID.isValid(""))
        XCTAssertNoThrow(try SnappyBTUUID.validate(["180F", testService]))
        XCTAssertThrowsError(try SnappyBTUUID.validate(["180F", "nope"]))
    }

    func testErrorDescriptions() {
        let id = UUID()
        let all: [SnappyBTError] = [
            .invalidUUID("x"), .unknownPeripheral(id), .connectionFailed("a"),
            .discoveryFailed("b"), .writeFailed("c"), .connectionLimitReached(2),
        ]
        XCTAssertEqual(all.compactMap(\.errorDescription).count, all.count)
        XCTAssertTrue(all[1].errorDescription!.contains(id.uuidString))
        XCTAssertEqual(SnappyBTError.reason(nil), "unknown error")
        XCTAssertEqual(SnappyBTError.reason(TestError()), "synthetic failure")
    }

    func testDiscoveredPeripheral() {
        let id = UUID()
        let d = SnappyBTDiscoveredPeripheral(identifier: id, name: "Device", rssi: -50, serviceUUIDs: ["180F"], manufacturerData: Data([1]))
        XCTAssertEqual(d.identifier, id)
        XCTAssertEqual(d.name, "Device")
        XCTAssertEqual(d.rssi, -50)
        XCTAssertEqual(d.serviceUUIDs, ["180F"])
        XCTAssertEqual(d.manufacturerData, Data([1]))
        XCTAssertEqual(SnappyBTDiscoveredPeripheral(identifier: id, name: nil, rssi: 0).serviceUUIDs, [])
    }
}
