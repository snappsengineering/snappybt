import Foundation

public final class SnappyBTCentral: @unchecked Sendable {

    // MARK: - Properties

    private let config: SnappyBTCentralConfig
    private let driver: SnappyBTCentralDriver
    private let storage: Locked<SnappyBTCentralStorage>

    public var onDiscover: (@Sendable (SnappyBTDiscoveredPeripheral) -> Void)? {
        get { storage.withLock { $0.onDiscover } }
        set { storage.withLock { $0.onDiscover = newValue } }
    }
    public var onConnect: (@Sendable (UUID) -> Void)? {
        get { storage.withLock { $0.onConnect } }
        set { storage.withLock { $0.onConnect = newValue } }
    }
    public var onDisconnect: (@Sendable (UUID, Error?) -> Void)? {
        get { storage.withLock { $0.onDisconnect } }
        set { storage.withLock { $0.onDisconnect = newValue } }
    }
    public var onError: (@Sendable (SnappyBTError) -> Void)? {
        get { storage.withLock { $0.onError } }
        set { storage.withLock { $0.onError = newValue } }
    }
    public var onReadyToWrite: (@Sendable (UUID) -> Void)? {
        get { storage.withLock { $0.onReadyToWrite } }
        set { storage.withLock { $0.onReadyToWrite = newValue } }
    }
    public var onStateChanged: (@Sendable (SnappyBTState) -> Void)? {
        get { storage.withLock { $0.onStateChanged } }
        set { storage.withLock { $0.onStateChanged = newValue } }
    }

    public var state: SnappyBTState { storage.withLock { $0.state } }
    public var connectedPeripherals: [UUID] {
        storage.withLock { $0.connected.sorted { $0.uuidString < $1.uuidString } }
    }
    public var readyPeripherals: [UUID] {
        storage.withLock { $0.ready.sorted { $0.uuidString < $1.uuidString } }
    }
    public var lastError: SnappyBTError? { storage.withLock { $0.lastError } }

    // MARK: - Lifecycle

    public init(config: SnappyBTCentralConfig, driver: SnappyBTCentralDriver) throws {
        try config.validate()
        self.config = config
        self.driver = driver
        self.storage = Locked(SnappyBTCentralStorage(state: driver.state))
        driver.onEvent = { [weak self] event in self?.handle(event) }
    }

    // MARK: - Scan

    public func startScanning() {
        let start = storage.withLock { s -> Bool in
            s.scanRequested = true
            guard s.state == .poweredOn, !s.scanning else { return false }
            s.scanning = true
            return true
        }
        if start { driver.startScan(serviceUUIDs: config.serviceUUIDs, allowDuplicates: config.allowDuplicates) }
    }

    public func stopScanning() {
        storage.withLock { s in
            s.scanRequested = false
            s.scanning = false
        }
        driver.stopScan()
    }

    // MARK: - Connect

    public func connect(to identifier: UUID) {
        let limit = max(1, config.maxConnections)
        enum Outcome { case connect, ignore, fail(SnappyBTError) }
        let outcome = storage.withLock { s -> Outcome in
            guard s.known.contains(identifier) else { return .fail(.unknownPeripheral(identifier)) }
            if s.connecting.contains(identifier) || s.connected.contains(identifier) { return .ignore }
            guard s.connecting.count + s.connected.count < limit else { return .fail(.connectionLimitReached(limit)) }
            s.connecting.insert(identifier)
            return .connect
        }
        switch outcome {
        case .connect: driver.connect(identifier)
        case .ignore: break
        case .fail(let error): report(error)
        }
    }

    // MARK: - Write

    public func write(data: Data) {
        guard let payload = seal(data) else { return }
        let targets = storage.withLock { s -> [UUID] in
            if s.ready.isEmpty { s.pendingAny.append(payload) }
            return s.ready.sorted { $0.uuidString < $1.uuidString }
        }
        for id in targets { driver.write(payload, to: id) }
    }

    public func write(data: Data, to identifier: UUID) {
        guard let payload = seal(data) else { return }
        let ready = storage.withLock { s -> Bool in
            guard s.ready.contains(identifier) else {
                s.pending[identifier, default: []].append(payload)
                return false
            }
            return true
        }
        if ready { driver.write(payload, to: identifier) }
    }

    public func write(text: String) {
        write(data: Data(text.utf8))
    }

    public func write(text: String, to identifier: UUID) {
        write(data: Data(text.utf8), to: identifier)
    }

    // MARK: - Disconnect

    public func disconnect(from identifier: UUID) {
        let wasActive = storage.withLock { s -> Bool in
            let active = s.connecting.contains(identifier)
                || s.connected.contains(identifier)
                || s.ready.contains(identifier)
            s.connecting.remove(identifier)
            s.connected.remove(identifier)
            s.ready.remove(identifier)
            s.pending[identifier] = nil
            return active
        }
        if wasActive { driver.disconnect(identifier) }
    }

    public func disconnect() {
        let ids = storage.withLock { s -> [UUID] in
            let all = s.connecting.union(s.connected).union(s.ready)
                .sorted { $0.uuidString < $1.uuidString }
            s.connecting = []
            s.connected = []
            s.ready = []
            s.pending = [:]
            s.pendingAny = []
            return all
        }
        for id in ids { driver.disconnect(id) }
    }

    public func clearError() {
        storage.withLock { $0.lastError = nil }
    }

    // MARK: - Driver events

    private func handle(_ event: SnappyBTCentralDriverEvent) {
        switch event {
        case .stateChanged(let newState):
            let start = storage.withLock { s -> Bool in
                s.state = newState
                guard newState == .poweredOn else {
                    s.scanning = false
                    return false
                }
                guard s.scanRequested, !s.scanning else { return false }
                s.scanning = true
                return true
            }
            dispatch { $0.onStateChanged?(newState) }
            if start { driver.startScan(serviceUUIDs: config.serviceUUIDs, allowDuplicates: config.allowDuplicates) }

        case .discovered(let peripheral):
            storage.withLock { _ = $0.known.insert(peripheral.identifier) }
            dispatch { $0.onDiscover?(peripheral) }

        case .connected(let id):
            storage.withLock { s in
                s.connecting.remove(id)
                s.connected.insert(id)
            }
            dispatch { $0.onConnect?(id) }

        case .connectionFailed(let id, let error):
            storage.withLock { _ = $0.connecting.remove(id) }
            report(.connectionFailed(SnappyBTError.reason(error)))

        case .disconnected(let id, let error):
            storage.withLock { s in
                s.known.remove(id)
                s.connecting.remove(id)
                s.connected.remove(id)
                s.ready.remove(id)
                s.pending[id] = nil
            }
            dispatch { $0.onDisconnect?(id, error) }

        case .readyToWrite(let id):
            let queued = storage.withLock { s -> [Data] in
                s.ready.insert(id)
                let targeted = s.pending.removeValue(forKey: id) ?? []
                let any = s.pendingAny
                s.pendingAny = []
                return any + targeted
            }
            dispatch { $0.onReadyToWrite?(id) }
            for data in queued { driver.write(data, to: id) }

        case .writeCompleted(_, let error):
            if let error { report(.writeFailed(SnappyBTError.reason(error))) }

        case .discoveryFailed(_, let error):
            report(.discoveryFailed(SnappyBTError.reason(error)))
        }
    }

    // MARK: - Helpers

    private func seal(_ data: Data) -> Data? {
        do {
            return try config.encryption.sealedPayload(from: data)
        } catch {
            report(.writeFailed("encryption: \(SnappyBTError.reason(error))"))
            return nil
        }
    }

    private func report(_ error: SnappyBTError) {
        storage.withLock { $0.lastError = error }
        dispatch { $0.onError?(error) }
    }

    private func dispatch(_ body: @escaping @Sendable (SnappyBTCentralCallbackSet) -> Void) {
        let callbacks = storage.withLock { SnappyBTCentralCallbackSet($0) }
        config.callbackQueue.async { body(callbacks) }
    }
}
