@preconcurrency import CoreBluetooth
import Foundation

public final class CoreBluetoothCentralDriver: NSObject, SnappyBTCentralDriver, @unchecked Sendable {
    private let queue: DispatchQueue
    private let receiveUUID: CBUUID
    private let handler = Locked<(@Sendable (SnappyBTCentralDriverEvent) -> Void)?>(nil)
    private var manager: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var characteristics: [UUID: CBCharacteristic] = [:]

    public init(
        receiveCharacteristicUUID: String = SnappyBTDefaultRXCharacteristicUUID,
        queue: DispatchQueue = DispatchQueue(label: "snappybt.central")
    ) {
        self.queue = queue
        self.receiveUUID = CBUUID(string: receiveCharacteristicUUID)
        super.init()
        self.manager = CBCentralManager(delegate: self, queue: queue)
    }

    public var state: SnappyBTState { SnappyBTState(manager.state) }

    public var onEvent: (@Sendable (SnappyBTCentralDriverEvent) -> Void)? {
        get { handler.withLock { $0 } }
        set { handler.withLock { $0 = newValue } }
    }

    private func emit(_ event: SnappyBTCentralDriverEvent) { onEvent?(event) }

    public func startScan(serviceUUIDs: [String], allowDuplicates: Bool) {
        queue.async {
            self.manager.scanForPeripherals(
                withServices: serviceUUIDs.map { CBUUID(string: $0) },
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
            )
        }
    }

    public func stopScan() {
        queue.async { self.manager.stopScan() }
    }

    public func connect(_ identifier: UUID) {
        queue.async {
            guard let peripheral = self.peripherals[identifier] else { return }
            self.manager.connect(peripheral, options: nil)
        }
    }

    public func disconnect(_ identifier: UUID) {
        queue.async {
            guard let peripheral = self.peripherals[identifier] else { return }
            self.manager.cancelPeripheralConnection(peripheral)
        }
    }

    public func write(_ data: Data, to identifier: UUID) {
        queue.async {
            guard let peripheral = self.peripherals[identifier],
                  let characteristic = self.characteristics[identifier] else { return }
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension CoreBluetoothCentralDriver: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        emit(.stateChanged(SnappyBTState(central.state)))
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        peripherals[peripheral.identifier] = peripheral
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        emit(.discovered(SnappyBTDiscoveredPeripheral(
            identifier: peripheral.identifier,
            name: advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name,
            rssi: RSSI.intValue,
            serviceUUIDs: services.map(\.uuidString),
            manufacturerData: advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        )))
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        emit(.connected(peripheral.identifier))
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        emit(.connectionFailed(peripheral.identifier, error))
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        characteristics[peripheral.identifier] = nil
        peripherals[peripheral.identifier] = nil
        emit(.disconnected(peripheral.identifier, error))
    }
}

// MARK: - CBPeripheralDelegate

extension CoreBluetoothCentralDriver: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            emit(.discoveryFailed(peripheral.identifier, error))
            return
        }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics([receiveUUID], for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            emit(.discoveryFailed(peripheral.identifier, error))
            return
        }
        guard let match = service.characteristics?.first(where: { $0.uuid == receiveUUID }) else { return }
        characteristics[peripheral.identifier] = match
        emit(.readyToWrite(peripheral.identifier))
    }

    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        emit(.writeCompleted(peripheral.identifier, error))
    }
}

// MARK: - SnappyBTCentral

extension SnappyBTCentral {
    public static func live(config: SnappyBTCentralConfig) throws -> SnappyBTCentral {
        try config.validate()
        return try SnappyBTCentral(
            config: config,
            driver: CoreBluetoothCentralDriver(receiveCharacteristicUUID: config.receiveCharacteristicUUID)
        )
    }
}
