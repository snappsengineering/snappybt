import CryptoKit
import XCTest
@testable import SnappyBT

// MARK: - EncryptionTests

final class EncryptionTests: XCTestCase {

    // MARK: - Encrypt and decrypt

    func testRoundTrip() throws {
        let enc = Encryption(key: Encryption.generateKey())
        let original = Data("Hello, World!".utf8)
        let encrypted = try enc.encrypt(original)
        let decrypted = try enc.decrypt(encrypted)
        XCTAssertEqual(decrypted, original)
        XCTAssertNotEqual(encrypted, original)
    }

    func testKeyStringInit() throws {
        let enc = Encryption(keyString: "my-secret-password")
        let data = Data("test".utf8)
        let encrypted = try enc.encrypt(data)
        let decrypted = try enc.decrypt(encrypted)
        XCTAssertEqual(decrypted, data)
    }

    func testWrongKeyFails() throws {
        let enc1 = Encryption(key: Encryption.generateKey())
        let enc2 = Encryption(key: Encryption.generateKey())
        let encrypted = try enc1.encrypt(Data("secret".utf8))
        XCTAssertThrowsError(try enc2.decrypt(encrypted))
    }

    func testDecryptThrowsOnMalformedData() {
        let enc = Encryption(key: Encryption.generateKey())
        XCTAssertThrowsError(try enc.decrypt(Data("not-a-sealed-box".utf8)))
    }

    func testEncryptFailureSurfacesEncryptionError() {
        let badKey = SymmetricKey(data: Data(repeating: 1, count: 17))
        let enc = Encryption(key: badKey)
        XCTAssertThrowsError(try enc.encrypt(Data("x".utf8))) { error in
            guard case EncryptionError.encryptionFailed = error else {
                return XCTFail("Expected encryptionFailed, got \(error)")
            }
        }
    }

    func testSymmetricKeyFromEmptyDataIsNil() {
        XCTAssertNil(SymmetricKey(dataRepresentation: Data()))
    }

    func testSymmetricKeyDataRoundTrip() {
        let key = Encryption.generateKey()
        let restored = SymmetricKey(dataRepresentation: key.dataRepresentation)
        XCTAssertEqual(restored?.dataRepresentation, key.dataRepresentation)
    }

    func testOptionalPassthrough() throws {
        let none: Encryption? = nil
        let data = Data("plain".utf8)
        XCTAssertEqual(try none.sealedPayload(from: data), data)
        XCTAssertEqual(try none.openedPayload(from: data), data)
        let some: Encryption? = Encryption(key: Encryption.generateKey())
        let sealed = try some.sealedPayload(from: data)
        XCTAssertNotEqual(sealed, data)
        XCTAssertEqual(try some.openedPayload(from: sealed), data)
    }

    func testErrorDescriptions() {
        struct Fake: Error {}
        XCTAssertNotNil(EncryptionError.encryptionFailed(Fake()).errorDescription)
        XCTAssertNotNil(EncryptionError.decryptionFailed(Fake()).errorDescription)
        XCTAssertEqual(EncryptionError.invalidData.errorDescription, "Invalid encrypted data")
    }
}
