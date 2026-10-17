import Foundation

enum SnappyBTUUID {

    // MARK: - Public

    static func isValid(_ value: String) -> Bool {
        if UUID(uuidString: value) != nil { return true }
        guard value.count == 4 || value.count == 8 else { return false }
        return value.allSatisfy(\.isHexDigit)
    }

    static func validate(_ values: [String]) throws {
        for value in values where !isValid(value) {
            throw SnappyBTError.invalidUUID(value)
        }
    }
}
