import Foundation
import Security

enum KeychainService {

    private static let serviceName = "com.hypr.tv"

    enum Key: String {
        case serverURL = "server_url"
        case accessToken = "access_token"
        case userId = "user_id"
    }

    // MARK: - Public API

    /// Saves a string value to the keychain for the given key.
    /// If the key already exists, the value is updated in place.
    static func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Attempt to update first; if the item doesn't exist, add it.
        let existingQuery = baseQuery(for: key)
        let status = SecItemCopyMatching(existingQuery as CFDictionary, nil)

        if status == errSecSuccess {
            let updateAttributes: [CFString: Any] = [
                kSecValueData: data
            ]
            let updateStatus = SecItemUpdate(existingQuery as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if status == errSecItemNotFound {
            var addQuery = baseQuery(for: key)
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieves a string value from the keychain for the given key.
    /// Returns nil if the key does not exist.
    static func get(_ key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes a single key from the keychain.
    static func delete(_ key: Key) {
        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)
    }

    /// Deletes all keys managed by this service from the keychain.
    static func deleteAll() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private Helpers

    private static func baseQuery(for key: Key) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key.rawValue,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
    }

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case encodingFailed
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "Failed to encode the value as UTF-8 data."
            case .unexpectedStatus(let status):
                return "Keychain operation returned unexpected status: \(status)"
            }
        }
    }
}
