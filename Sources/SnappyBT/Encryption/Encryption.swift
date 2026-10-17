import CryptoKit
import Foundation

// MARK: - Encryption

public struct Encryption: Sendable {

    // MARK: - Properties

    private let key: SymmetricKey

    // MARK: - Lifecycle

    public init(key: SymmetricKey) {
        self.key = key
    }

    public init(keyString: String) {
        let hash = SHA256.hash(data: Data(keyString.utf8))
        self.key = SymmetricKey(data: hash)
    }

    // MARK: - Public

    public static func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    public func encrypt(_ data: Data) throws -> Data {
        do {
            return try AES.GCM.seal(data, using: key).combined!
        } catch {
            throw EncryptionError.encryptionFailed(error)
        }
    }

    public func decrypt(_ data: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw EncryptionError.decryptionFailed(error)
        }
    }
}

// MARK: - Optional Encryption

extension Encryption? {

    func sealedPayload(from data: Data) throws -> Data {
        guard let encryption = self else { return data }
        return try encryption.encrypt(data)
    }

    func openedPayload(from data: Data) throws -> Data {
        guard let encryption = self else { return data }
        return try encryption.decrypt(data)
    }
}
