import Foundation

public final class SnappyBTPeripheral: @unchecked Sendable {

    // MARK: - Properties

    private let config: SnappyBTPeripheralConfig
    private let driver: SnappyBTPeripheralDriver
    private let storage: Locked<SnappyBTPeripheralStorage>

    public var onReceive: (@Sendable (Data) -> Void)? {
        get { storage.withLock { $0.onReceive } }
        set { storage.withLock { $0.onReceive = newValue } }
    }
    public var onReceiveText: (@Sendable (String) -> Void)? {
        get { storage.withLock { $0.onReceiveText } }
        set { storage.withLock { $0.onReceiveText = newValue } }
    }
    public var onMessage: (@Sendable (SnappyBTMessage) -> Void)? {
        get { storage.withLock { $0.onMessage } }
        set { storage.withLock { $0.onMessage = newValue } }
    }
    public var onStateChanged: (@Sendable (SnappyBTState) -> Void)? {
        get { storage.withLock { $0.onStateChanged } }
        set { storage.withLock { $0.onStateChanged = newValue } }
    }
    public var onError: (@Sendable (SnappyBTError) -> Void)? {
        get { storage.withLock { $0.onError } }
        set { storage.withLock { $0.onError = newValue } }
    }

    public var state: SnappyBTState { storage.withLock { $0.state } }
    public var isAdvertising: Bool { driver.isAdvertising }
    public var lastError: SnappyBTError? { storage.withLock { $0.lastError } }

    // MARK: - Lifecycle

    public init(config: SnappyBTPeripheralConfig, driver: SnappyBTPeripheralDriver) throws {
        try config.validate()
        self.config = config
        self.driver = driver
        self.storage = Locked(SnappyBTPeripheralStorage(state: driver.state))
        driver.onEvent = { [weak self] event in self?.handle(event) }
    }

    // MARK: - Advertising

    public func startAdvertising() {
        let start = storage.withLock { s -> Bool in
            s.advertisingRequested = true
            return s.state == .poweredOn
        }
        if start { publish() }
    }

    public func stopAdvertising() {
        storage.withLock { $0.advertisingRequested = false }
        driver.stopAdvertising()
    }

    public func clearError() {
        storage.withLock { $0.lastError = nil }
    }

    // MARK: - Driver events

    private func handle(_ event: SnappyBTPeripheralDriverEvent) {
        switch event {
        case .stateChanged(let newState):
            let start = storage.withLock { s -> Bool in
                s.state = newState
                return newState == .poweredOn && s.advertisingRequested
            }
            let callback = storage.withLock { $0.onStateChanged }
            config.callbackQueue.async { callback?(newState) }
            if start { publish() }

        case .received(let data, let sender, let respond):
            guard !data.isEmpty else {
                respond(false)
                return
            }
            let opened: Data
            do {
                opened = try config.encryption.openedPayload(from: data)
            } catch {
                respond(false)
                report(.writeFailed("decryption: \(SnappyBTError.reason(error))"))
                return
            }
            respond(true)
            let (onReceive, onText, onMessage) = storage.withLock { ($0.onReceive, $0.onReceiveText, $0.onMessage) }
            config.callbackQueue.async {
                onReceive?(opened)
                if let text = String(data: opened, encoding: .utf8) { onText?(text) }
                onMessage?(SnappyBTMessage(sender: sender, data: opened))
            }
        }
    }

    // MARK: - Helpers

    private func publish() {
        if let securing = driver as? SnappyBTLinkSecuring {
            securing.requireEncryptedLink = config.requireEncryptedLink
        }
        driver.startAdvertising(
            serviceUUID: config.serviceUUID,
            receiveCharacteristicUUID: config.receiveCharacteristicUUID,
            localName: config.localName.isEmpty ? nil : config.localName
        )
    }

    private func report(_ error: SnappyBTError) {
        storage.withLock { $0.lastError = error }
        let callback = storage.withLock { $0.onError }
        config.callbackQueue.async { callback?(error) }
    }
}
