@preconcurrency import CoreBluetooth
import Foundation

public final class CoreBluetoothPeripheralDriver: NSObject, SnappyBTPeripheralDriver, SnappyBTLinkSecuring, @unchecked Sendable {
    private let queue: DispatchQueue
    private let handler = Locked<(@Sendable (SnappyBTPeripheralDriverEvent) -> Void)?>(nil)
    private var manager: CBPeripheralManager!
    private var serviceAdded = false
    public var requireEncryptedLink = false

    public init(queue: DispatchQueue = DispatchQueue(label: "snappybt.peripheral")) {
        self.queue = queue
        super.init()
        self.manager = CBPeripheralManager(delegate: self, queue: queue)
    }

    public var state: SnappyBTState { SnappyBTState(manager.state) }
    public var isAdvertising: Bool { manager.isAdvertising }

    public var onEvent: (@Sendable (SnappyBTPeripheralDriverEvent) -> Void)? {
        get { handler.withLock { $0 } }
        set { handler.withLock { $0 = newValue } }
    }

    private func emit(_ event: SnappyBTPeripheralDriverEvent) { onEvent?(event) }

    public func startAdvertising(serviceUUID: String, receiveCharacteristicUUID: String, localName: String?) {
        let encrypted = requireEncryptedLink
        queue.async {
            let service = CBUUID(string: serviceUUID)
            let rx = CBUUID(string: receiveCharacteristicUUID)
            if !self.serviceAdded {
                let permissions: CBAttributePermissions = encrypted
                    ? [.writeEncryptionRequired]
                    : [.writeable]
                let mutable = CBMutableService(type: service, primary: true)
                mutable.characteristics = [
                    CBMutableCharacteristic(type: rx, properties: [.write], value: nil, permissions: permissions)
                ]
                self.manager.add(mutable)
                self.serviceAdded = true
            }
            if self.manager.isAdvertising { self.manager.stopAdvertising() }
            var advertisement: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [service]]
            if let localName { advertisement[CBAdvertisementDataLocalNameKey] = localName }
            self.manager.startAdvertising(advertisement)
        }
    }

    public func stopAdvertising() {
        queue.async { if self.manager.isAdvertising { self.manager.stopAdvertising() } }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension CoreBluetoothPeripheralDriver: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        emit(.stateChanged(SnappyBTState(peripheral.state)))
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        let manager = UncheckedSendable(value: peripheral)
        for (index, request) in requests.enumerated() {
            let box = UncheckedSendable(value: request)
            emit(.received(request.value ?? Data(), from: request.central.identifier, respond: { accepted in
                guard index == 0 else { return }
                manager.value.respond(to: box.value, withResult: accepted ? .success : .invalidAttributeValueLength)
            }))
        }
    }
}

// MARK: - SnappyBTPeripheral

extension SnappyBTPeripheral {
    public static func live(config: SnappyBTPeripheralConfig) throws -> SnappyBTPeripheral {
        try config.validate()
        return try SnappyBTPeripheral(config: config, driver: CoreBluetoothPeripheralDriver())
    }
}
