@preconcurrency import CoreBluetooth
import Foundation


// MARK: - SnappyBTState

extension SnappyBTState {
    init(_ state: CBManagerState) {
        switch state {
        case .resetting: self = .resetting
        case .unsupported: self = .unsupported
        case .unauthorized: self = .unauthorized
        case .poweredOff: self = .poweredOff
        case .poweredOn: self = .poweredOn
        case .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }
}

struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}
